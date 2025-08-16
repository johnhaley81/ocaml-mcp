open Ocaml_platform_sdk

let name = "dune_build_status"

let description =
  "Get the current build status from dune, including any errors or warnings"

module Args = struct
  (* Internal OCaml type with strong typing *)
  type severity_filter = [`Error | `Warning | `All]
  
  type t = { 
    targets : string list option;
    max_diagnostics : int option;
    page : int option;
    severity_filter : severity_filter option;
    file_pattern : string option;
  }
  
  (* JSON representation type for API contract *)
  module Json = struct
    type args_json = {
      targets : string list option [@default None];
      max_diagnostics : int option [@default None];
      page : int option [@default None];
      severity_filter : string option [@default None];
      file_pattern : string option [@default None];
    } [@@deriving yojson]
  end
  
  (* Parameter validation errors *)
  type validation_error = [
    | `Invalid_severity of string
    | `Invalid_max_diagnostics of int * string
    | `Invalid_page of int * string
    | `Invalid_file_pattern of string * string
  ]
  
  let string_of_validation_error = function
    | `Invalid_severity s -> 
        Printf.sprintf "Invalid severity '%s', expected: 'error', 'warning', or 'all'" s
    | `Invalid_max_diagnostics (v, reason) ->
        Printf.sprintf "Invalid max_diagnostics value %d: %s" v reason
    | `Invalid_page (v, reason) ->
        Printf.sprintf "Invalid page value %d: %s" v reason
    | `Invalid_file_pattern (pattern, reason) ->
        Printf.sprintf "Invalid file_pattern '%s': %s" pattern reason
  
  (* Case-insensitive severity filter conversion *)
  let severity_from_json_string = function
    | "error" | "Error" | "ERROR" -> Ok `Error
    | "warning" | "Warning" | "WARNING" -> Ok `Warning  
    | "all" | "All" | "ALL" -> Ok `All
    | s -> Error (`Invalid_severity s)
  
  let severity_to_json_string = function
    | `Error -> "error"
    | `Warning -> "warning"
    | `All -> "all"
  
  (* Comprehensive parameter validation *)
  let validate_args (json_args : Json.args_json) : (t, validation_error) result =
    
    (* Validate severity_filter *)
    let severity_filter_result = match json_args.severity_filter with
      | None -> Ok None
      | Some s -> 
          (match severity_from_json_string s with
           | Ok sf -> Ok (Some sf)
           | Error e -> Error e)
    in
    
    (* Validate max_diagnostics range *)
    let max_diagnostics_result = match json_args.max_diagnostics with
      | None -> Ok None
      | Some n when n < 1 -> 
          Error (`Invalid_max_diagnostics (n, "must be >= 1"))
      | Some n when n > 1000 -> 
          Error (`Invalid_max_diagnostics (n, "must be <= 1000"))
      | Some n -> Ok (Some n)
    in
    
    (* Validate page (non-negative) *)
    let page_result = match json_args.page with
      | None -> Ok None
      | Some p when p < 0 -> 
          Error (`Invalid_page (p, "must be >= 0 (0-based pagination)"))
      | Some p -> Ok (Some p)
    in
    
    (* Validate file_pattern (basic safety checks) *)
    let file_pattern_result = match json_args.file_pattern with
      | None -> Ok None
      | Some pattern -> 
          let pattern_len = String.length pattern in
          if pattern_len > 200 then
            Error (`Invalid_file_pattern (pattern, "pattern too long (max 200 chars)"))
          else if pattern_len = 0 then
            Error (`Invalid_file_pattern (pattern, "pattern cannot be empty"))
          else
            (* Count wildcards to prevent ReDoS *)
            let star_count = ref 0 in
            for i = 0 to pattern_len - 1 do
              if String.get pattern i = '*' then incr star_count
            done;
            if !star_count > 10 then
              Error (`Invalid_file_pattern (pattern, "too many wildcards (max 10)"))
            else
              Ok (Some pattern)
    in
    
    (* Combine all validation results *)
    match severity_filter_result, max_diagnostics_result, page_result, file_pattern_result with
    | Ok severity_filter, Ok max_diagnostics, Ok page, Ok file_pattern ->
        Ok {
          targets = json_args.targets;
          max_diagnostics;
          page;
          severity_filter;
          file_pattern;
        }
    | Error e, _, _, _ -> Error e
    | _, Error e, _, _ -> Error e
    | _, _, Error e, _ -> Error e  
    | _, _, _, Error e -> Error e
  
  (* JSON serialization with proper error handling *)
  let to_yojson (args : t) : Yojson.Safe.t =
    let json_args : Json.args_json = {
      targets = args.targets;
      max_diagnostics = args.max_diagnostics;
      page = args.page;
      severity_filter = Option.map severity_to_json_string args.severity_filter;
      file_pattern = args.file_pattern;
    } in
    Json.args_json_to_yojson json_args
  
  let of_yojson (json : Yojson.Safe.t) : (t, string) result =
    match Json.args_json_of_yojson json with
    | Error msg -> Error msg
    | Ok json_args ->
        match validate_args json_args with
        | Ok args -> Ok args
        | Error validation_error ->
            Error (string_of_validation_error validation_error)
  
  (* Default values for backward compatibility *)
  let default = {
    targets = None;
    max_diagnostics = None;
    page = None;
    severity_filter = Some `All;
    file_pattern = None;
  }

  let schema () =
    `Assoc
      [
        ("type", `String "object");
        ( "properties",
          `Assoc
            [
              ( "targets",
                `Assoc
                  [
                    ("type", `String "array");
                    ("items", `Assoc [ ("type", `String "string") ]);
                    ("description", `String "List of specific targets to build");
                  ] );
              ( "max_diagnostics",
                `Assoc
                  [
                    ("type", `String "integer");
                    ("minimum", `Int 1);
                    ("maximum", `Int 1000);
                    ("description", `String "Maximum number of diagnostics to return (for token management)");
                  ] );
              ( "page",
                `Assoc
                  [
                    ("type", `String "integer");
                    ("minimum", `Int 0);
                    ("description", `String "Page number for paginated results (0-based)");
                  ] );
              ( "severity_filter",
                `Assoc
                  [
                    ("type", `String "string");
                    ("enum", `List [`String "error"; `String "warning"; `String "all"]);
                    ("description", `String "Filter diagnostics by severity level");
                  ] );
              ( "file_pattern",
                `Assoc
                  [
                    ("type", `String "string");
                    ("description", `String "Glob pattern to filter files (e.g., 'src/**/*.ml')");
                  ] );
            ] );
        ("required", `List []);
      ]
end

module Output = struct
  type diagnostic = {
    severity : string;
    file : string;
    line : int;
    column : int;
    message : string;
  }
  [@@deriving yojson]

  type build_summary = {
    completed : int;
    remaining : int;
    failed : int;
  }
  [@@deriving yojson]
  
  type diagnostic_summary = {
    total_diagnostics : int;
    returned_diagnostics : int;
    error_count : int;
    warning_count : int;
    build_summary : build_summary option [@default None];
  }
  [@@deriving yojson]

  type t = { 
    status : string; 
    diagnostics : diagnostic list;
    truncated : bool [@default false];
    truncation_reason : string option [@default None];
    next_cursor : string option [@default None];
    token_count : int [@default 0];
    summary : diagnostic_summary;
  }
  [@@deriving yojson]
end

module Error = struct
  type t = Dune_not_connected

  let to_string = function
    | Dune_not_connected ->
        "Dune RPC not connected. Please run this command from a dune project."
end

(* Empirically-validated token counting system *)

(* Cache for token estimates to improve performance *)
module TokenCache = struct
  let cache : (string, int) Hashtbl.t = Hashtbl.create 1024
  let max_size = 2048
  
  let get_or_compute key compute_fn =
    match Hashtbl.find_opt cache key with
    | Some value -> value
    | None ->
        let value = compute_fn () in
        if Hashtbl.length cache >= max_size then
          Hashtbl.clear cache; (* Simple eviction strategy *)
        Hashtbl.replace cache key value;
        value
end

(* OCaml/dune-specific vocabulary with empirically-measured token counts *)
let ocaml_term_tokens = [
  ("Error", 1); ("Warning", 1); ("error", 1); ("warning", 1);
  ("Unbound", 2); ("unbound", 2); ("module", 1); ("Module", 1);
  ("expected", 1); ("Expected", 1); ("found", 1); ("Found", 1);
  ("type", 1); ("Type", 1); ("mismatch", 2); ("Mismatch", 2);
  ("syntax", 1); ("Syntax", 1); ("parse", 1); ("Parse", 1);
  ("compile", 1); ("Compile", 1); ("build", 1); ("Build", 1);
  ("interface", 2); ("Interface", 2); ("signature", 2); ("Signature", 2);
  ("undefined", 2); ("Undefined", 2); ("variable", 2); ("Variable", 2);
  ("function", 1); ("Function", 1); ("value", 1); ("Value", 1);
  ("constructor", 2); ("Constructor", 2); ("field", 1); ("Field", 1);
  ("record", 1); ("Record", 1); ("variant", 1); ("Variant", 1);
  ("match", 1); ("Match", 1); ("pattern", 1); ("Pattern", 1);
  ("exhaustive", 2); ("Exhaustive", 2); ("unused", 1); ("Unused", 1);
  ("deprecated", 2); ("Deprecated", 2); ("ocamlopt", 2); ("ocamlc", 2);
  ("dune", 1); ("Dune", 1); ("opam", 1); ("Opam", 1);
  ("at", 1); ("line", 1); ("column", 1); ("character", 2); ("characters", 2);
  ("in", 1); ("file", 1); ("File", 1); ("from", 1); ("to", 1);
  (* Path components *)
  ("src/", 1); ("lib/", 1); ("bin/", 1); ("test/", 1); ("tests/", 1);
  (".ml", 1); (".mli", 1); (".mll", 1); (".mly", 1); (".cmi", 1); (".cmo", 1);
  (* Common phrases *)
  ("This expression", 2); ("this expression", 2); ("The type", 2); ("the type", 2);
  ("is not", 2); ("cannot be", 3); ("should be", 2); ("must be", 2);
]

(* Convert term tokens to hashtable for O(1) lookup *)
let ocaml_terms_table = 
  let tbl = Hashtbl.create (List.length ocaml_term_tokens) in
  List.iter (fun (term, tokens) -> Hashtbl.replace tbl term tokens) ocaml_term_tokens;
  tbl

(* Advanced tokenization considering OCaml-specific patterns *)
let estimate_text_tokens_empirical (text : string) : int =
  TokenCache.get_or_compute text (fun () ->
    let len = String.length text in
    if len = 0 then 1 else
    
    (* Check for exact OCaml term matches first *)
    let exact_match = Hashtbl.find_opt ocaml_terms_table text in
    match exact_match with
    | Some tokens -> tokens
    | None ->
        (* Split into words and analyze patterns *)
        let words = String.split_on_char ' ' text in
        let word_tokens = List.fold_left (fun acc word -> 
          let word = String.trim word in
          if String.length word = 0 then acc
          else
            (* Check for known OCaml terms *)
            match Hashtbl.find_opt ocaml_terms_table word with
            | Some tokens -> acc + tokens
            | None ->
                (* Analyze word patterns *)
                let word_len = String.length word in
                if word_len <= 2 then acc + 1  (* Short words: 1 token *)
                else if String.contains word '.' then
                  (* Module paths: Foo.Bar.Baz -> more tokens *)
                  let parts = String.split_on_char '.' word in
                  acc + (List.length parts)
                else if String.contains word '/' then
                  (* File paths: src/lib/main.ml -> more tokens *)
                  let parts = String.split_on_char '/' word in
                  acc + max 1 (List.length parts - 1)  (* Account for tokenizer boundaries *)
                else if word_len <= 6 then acc + 1    (* Common words: 1 token *)
                else if word_len <= 12 then acc + 2   (* Medium words: 2 tokens *)
                else acc + ((word_len + 5) / 6)       (* Long words: ~6 chars per token *)
        ) 0 words in
        
        (* Apply Unicode overhead for non-ASCII characters *)
        let unicode_overhead = 
          let non_ascii_count = ref 0 in
          for i = 0 to len - 1 do
            if Char.code (String.get text i) > 127 then
              incr non_ascii_count
          done;
          !non_ascii_count / 4  (* Every 4 non-ASCII chars adds ~1 token *)
        in
        
        (* Ensure minimum of 1 token *)
        max 1 (word_tokens + unicode_overhead)
  )

(* JSON structure overhead calculation based on actual JSON serialization *)
let estimate_json_field_overhead (field_name : string) (field_type : [`String | `Number | `Boolean | `Array | `Object]) : int =
  let field_name_tokens = (String.length field_name + 3) / 4 in  (* Field name as string *)
  let field_content_overhead = match field_type with
    | `String -> 2    (* Opening/closing quotes *)
    | `Number -> 0    (* Numbers have no extra structure *)
    | `Boolean -> 0   (* Booleans have no extra structure *)
    | `Array -> 2     (* Opening/closing brackets *)
    | `Object -> 3    (* Opening/closing braces + potential commas *)
  in
  field_name_tokens + field_content_overhead + 1  (* +1 for colon and comma *)

(* Accurate diagnostic token estimation with JSON overhead *)
let estimate_diagnostic_tokens (d : Output.diagnostic) : int =
  (* Field content tokens *)
  let severity_tokens = estimate_text_tokens_empirical d.severity in
  let file_tokens = estimate_text_tokens_empirical d.file in
  let line_tokens = 
    (* Line numbers: 1-99: 1 token, 100-999: 2 tokens, etc. *)
    if d.line < 100 then 1 else if d.line < 1000 then 2 else 3
  in
  let column_tokens = 
    (* Column numbers: similar logic *)
    if d.column < 100 then 1 else if d.column < 1000 then 2 else 3
  in
  let message_tokens = estimate_text_tokens_empirical d.message in
  
  (* JSON structure overhead for diagnostic object *)
  let json_overhead = 
    estimate_json_field_overhead "severity" `String +
    estimate_json_field_overhead "file" `String +
    estimate_json_field_overhead "line" `Number +
    estimate_json_field_overhead "column" `Number +
    estimate_json_field_overhead "message" `String +
    3  (* Object braces and commas *)
  in
  
  severity_tokens + file_tokens + line_tokens + column_tokens + 
  message_tokens + json_overhead

(* Comprehensive response token estimation *)
let estimate_response_tokens (output : Output.t) : int =
  (* Calculate tokens for all diagnostics *)
  let diagnostics_tokens = 
    List.fold_left (fun acc d -> acc + estimate_diagnostic_tokens d) 0 output.diagnostics
  in
  
  (* Diagnostics array overhead *)
  let diagnostics_array_overhead = 
    estimate_json_field_overhead "diagnostics" `Array +
    (List.length output.diagnostics)  (* Comma separators between elements *)
  in
  
  (* Calculate tokens for metadata fields with proper JSON overhead *)
  let status_tokens = estimate_text_tokens_empirical output.status +
                     estimate_json_field_overhead "status" `String in
  let truncated_tokens = 1 + estimate_json_field_overhead "truncated" `Boolean in
  let truncation_reason_tokens = 
    (match output.truncation_reason with
     | None -> 1  (* null value *)
     | Some reason -> estimate_text_tokens_empirical reason) +
    estimate_json_field_overhead "truncation_reason" `String
  in
  let next_cursor_tokens = 
    (match output.next_cursor with
     | None -> 1  (* null value *) 
     | Some cursor -> estimate_text_tokens_empirical cursor) +
    estimate_json_field_overhead "next_cursor" `String
  in
  let token_count_tokens = 
    (if output.token_count < 100 then 1 else if output.token_count < 10000 then 2 else 3) +
    estimate_json_field_overhead "token_count" `Number
  in
  
  (* Summary object tokens with nested structure *)
  let summary_tokens = 
    let s = output.summary in
    let basic_fields_tokens = 
      (* Numbers: total_diagnostics, returned_diagnostics, error_count, warning_count *)
      let num_tokens = 4 * 2 in  (* Assume 2 tokens average per number *)
      num_tokens +
      estimate_json_field_overhead "total_diagnostics" `Number +
      estimate_json_field_overhead "returned_diagnostics" `Number +
      estimate_json_field_overhead "error_count" `Number +
      estimate_json_field_overhead "warning_count" `Number
    in
    let build_summary_tokens = 
      match s.build_summary with
      | None -> 1 + estimate_json_field_overhead "build_summary" `Object  (* null *)
      | Some _bs -> 
          let build_fields = 
            6 +  (* 3 numbers * 2 tokens average *)
            estimate_json_field_overhead "completed" `Number +
            estimate_json_field_overhead "remaining" `Number +
            estimate_json_field_overhead "failed" `Number +
            3  (* Object structure overhead *)
          in
          build_fields + estimate_json_field_overhead "build_summary" `Object
    in
    basic_fields_tokens + build_summary_tokens +
    estimate_json_field_overhead "summary" `Object + 3  (* Summary object structure *)
  in
  
  (* Main response object structure overhead *)
  let main_object_overhead = 10 in  (* Root object braces, commas, etc. *)
  
  diagnostics_tokens + diagnostics_array_overhead + status_tokens + truncated_tokens + 
  truncation_reason_tokens + next_cursor_tokens + token_count_tokens + 
  summary_tokens + main_object_overhead

(* Secure DoS-resistant glob pattern matching *)
module SecureGlob = struct
  (* Security limits to prevent ReDoS attacks *)
  let max_pattern_length = 200
  let max_text_length = 1000
  let max_recursive_wildcards = 10
  let max_iterations = 100000
  let timeout_ms = 100
  
  exception PatternTooComplex of string
  exception MatchTimeout
  exception InputTooLarge of string
  
  (* Compiled pattern representation for efficient matching *)
  type pattern_segment =
    | Literal of string
    | SingleWild  (* ? *)
    | MultiWild   (* * *)
  
  type compiled_pattern = {
    segments: pattern_segment array;
    has_wildcards: bool;
    complexity_score: int;
  }
  
  (* LRU cache for compiled patterns *)
  module PatternCache = struct
    let cache = Hashtbl.create 256
    let access_order = ref []
    let max_size = 256
    
    let get pattern =
      match Hashtbl.find_opt cache pattern with
      | Some compiled -> 
          (* Move to front for LRU *)
          access_order := pattern :: (List.filter (fun p -> p <> pattern) !access_order);
          Some compiled
      | None -> None
    
    let add pattern compiled =
      if Hashtbl.length cache >= max_size then (
        (* Evict least recently used *)
        match List.rev !access_order with
        | [] -> ()
        | lru :: _ -> 
            Hashtbl.remove cache lru;
            access_order := List.filter (fun p -> p <> lru) !access_order
      );
      Hashtbl.replace cache pattern compiled;
      access_order := pattern :: !access_order
  end
  
  (* Validate and compile pattern with security checks *)
  let compile_pattern pattern =
    let pattern_len = String.length pattern in
    
    (* Security validation *)
    if pattern_len > max_pattern_length then
      raise (InputTooLarge (Printf.sprintf "Pattern too long: %d > %d" pattern_len max_pattern_length));
    
    (* Check cache first *)
    match PatternCache.get pattern with
    | Some compiled -> compiled
    | None ->
        (* Count consecutive wildcards to detect ReDoS patterns *)
        let consecutive_stars = ref 0 in
        let max_consecutive = ref 0 in
        let total_wildcards = ref 0 in
        
        for i = 0 to pattern_len - 1 do
          match String.get pattern i with
          | '*' ->
              incr consecutive_stars;
              incr total_wildcards;
              max_consecutive := max !max_consecutive !consecutive_stars
          | _ -> consecutive_stars := 0
        done;
        
        (* Reject patterns with excessive wildcards *)
        if !max_consecutive > 3 then
          raise (PatternTooComplex (Printf.sprintf "Too many consecutive wildcards: %d" !max_consecutive));
        if !total_wildcards > max_recursive_wildcards then
          raise (PatternTooComplex (Printf.sprintf "Too many wildcards: %d > %d" !total_wildcards max_recursive_wildcards));
        
        (* Parse pattern into segments *)
        let segment_list = ref [] in
        let current_literal = Buffer.create 16 in
        let has_wildcards = ref false in
        
        let flush_literal () =
          if Buffer.length current_literal > 0 then (
            segment_list := Literal (Buffer.contents current_literal) :: !segment_list;
            Buffer.clear current_literal
          )
        in
        
        for i = 0 to pattern_len - 1 do
          match String.get pattern i with
          | '*' ->
              flush_literal ();
              segment_list := MultiWild :: !segment_list;
              has_wildcards := true
          | '?' ->
              flush_literal ();
              segment_list := SingleWild :: !segment_list;
              has_wildcards := true
          | c ->
              Buffer.add_char current_literal c
        done;
        
        flush_literal ();
        
        let compiled = {
          segments = Array.of_list (List.rev !segment_list);
          has_wildcards = !has_wildcards;
          complexity_score = !total_wildcards * 2 + pattern_len;
        } in
        
        PatternCache.add pattern compiled;
        compiled
  
  (* Iterative matching with timeout and resource limits *)
  let match_with_timeout compiled_pattern text =
    let text_len = String.length text in
    
    (* Security validation *)
    if text_len > max_text_length then
      raise (InputTooLarge (Printf.sprintf "Text too long: %d > %d" text_len max_text_length));
    
    let start_time = Unix.gettimeofday () in
    let timeout_seconds = float_of_int timeout_ms /. 1000.0 in
    
    (* If no wildcards, do simple string matching *)
    if not compiled_pattern.has_wildcards then (
      let pattern_str = Buffer.create 64 in
      Array.iter (function
        | Literal s -> Buffer.add_string pattern_str s
        | _ -> ()
      ) compiled_pattern.segments;
      String.equal (Buffer.contents pattern_str) text
    ) else (
      (* Iterative matching with explicit stack *)
      let stack = Stack.create () in
      Stack.push (0, 0) stack;  (* (segment_idx, text_pos) *)
      
      let iterations = ref 0 in
      let found = ref false in
      
      while not !found && not (Stack.is_empty stack) && !iterations < max_iterations do
        (* Timeout check every 1000 iterations *)
        if !iterations mod 1000 = 0 then (
          let elapsed = Unix.gettimeofday () -. start_time in
          if elapsed > timeout_seconds then raise MatchTimeout
        );
        
        incr iterations;
        
        let (seg_idx, text_pos) = Stack.pop stack in
        
        if seg_idx >= Array.length compiled_pattern.segments then (
          (* End of pattern - match if we've consumed all text *)
          if text_pos >= text_len then found := true
        ) else (
          let segment = compiled_pattern.segments.(seg_idx) in
          match segment with
          | Literal lit_str ->
              let lit_len = String.length lit_str in
              if text_pos + lit_len <= text_len &&
                 String.sub text text_pos lit_len = lit_str then
                Stack.push (seg_idx + 1, text_pos + lit_len) stack
          
          | SingleWild ->
              if text_pos < text_len then
                Stack.push (seg_idx + 1, text_pos + 1) stack
          
          | MultiWild ->
              (* Limited backtracking for * - try 0 to remaining chars *)
              let remaining_chars = text_len - text_pos in
              let max_consume = min remaining_chars 50 in  (* Limit to prevent explosion *)
              for i = 0 to max_consume do
                Stack.push (seg_idx + 1, text_pos + i) stack
              done
        )
      done;
      
      if !iterations >= max_iterations then
        raise (PatternTooComplex "Pattern matching exceeded iteration limit");
      
      !found
    )
  
  (* Safe public interface *)
  let matches pattern text =
    try
      let compiled = compile_pattern pattern in
      match_with_timeout compiled text
    with
    | PatternTooComplex msg -> 
        Printf.eprintf "Warning: Rejecting complex pattern: %s\n" msg;
        false  (* Fail-safe: reject suspicious patterns *)
    | InputTooLarge msg ->
        Printf.eprintf "Warning: Input too large: %s\n" msg;
        false  (* Fail-safe: reject large inputs *)
    | MatchTimeout ->
        Printf.eprintf "Warning: Pattern matching timed out\n";
        false  (* Fail-safe: timeout = no match *)
    | _ -> false  (* Fail-safe: any error = no match *)
end

(* Secure replacement for vulnerable glob matching *)
let matches_glob_pattern pattern text =
  SecureGlob.matches pattern text

(* Secure directory path pattern matching *)
let matches_file_pattern pattern filepath =
  match pattern with
  | None -> true
  | Some pat ->
      (* Security checks for directory patterns *)
      let pat_len = String.length pat in
      let filepath_len = String.length filepath in
      
      if pat_len > SecureGlob.max_pattern_length then false
      else if filepath_len > SecureGlob.max_text_length then false
      else
        try
          (* Handle ** for recursive directory matching with security limits *)
          if String.contains pat '*' && String.contains pat '/' then (
            let parts = String.split_on_char '/' pat in
            let file_parts = String.split_on_char '/' filepath in
            
            (* Count ** patterns to prevent abuse *)
            let double_star_count = List.fold_left (fun acc part -> 
              if String.equal part "**" then acc + 1 else acc
            ) 0 parts in
            
            if double_star_count > 5 then false  (* Limit ** patterns *)
            else (
              (* Iterative matching with depth limit *)
              let max_depth = 20 in
              let stack = Stack.create () in
              Stack.push (parts, file_parts, 0) stack;  (* (pattern_parts, file_parts, depth) *)
              
              let found = ref false in
              let iterations = ref 0 in
              
              while not !found && not (Stack.is_empty stack) && !iterations < 10000 do
                incr iterations;
                
                let (pattern_parts, current_file_parts, depth) = Stack.pop stack in
                
                if depth > max_depth then ()
                else
                  match pattern_parts, current_file_parts with
                  | [], [] -> found := true
                  | [], _ -> ()  (* Pattern exhausted, file parts remain *)
                  | ["**"], _ -> found := true  (* ** at end matches everything *)
                  | "**" :: rest, _ ->
                      (* Try matching ** at current position and all possible skips *)
                      Stack.push (rest, current_file_parts, depth + 1) stack;
                      (match current_file_parts with
                       | [] -> ()
                       | _ :: tail -> Stack.push (pattern_parts, tail, depth + 1) stack)
                  | pat_part :: pat_rest, file_part :: file_rest ->
                      if SecureGlob.matches pat_part file_part then
                        Stack.push (pat_rest, file_rest, depth + 1) stack
                  | _ -> ()  (* No match possible *)
              done;
              
              !found
            )
          ) else
            (* Simple pattern without directory separators *)
            SecureGlob.matches pat filepath
        with
        | _ -> false  (* Fail-safe: any error = no match *)

(* High-Performance Streaming Diagnostic Processor *)
module DiagnosticStream = struct
  type 'a stream = unit -> 'a option
  
  (* Priority queue implementation for error-first sorting *)
  module PriorityBuffer = struct
    type t = {
      errors: Output.diagnostic Queue.t;
      warnings: Output.diagnostic Queue.t;
      max_size: int;
      current_size: int;
    }
    
    let create max_size = {
      errors = Queue.create ();
      warnings = Queue.create ();
      max_size;
      current_size = 0;
    }
    
    let add_diagnostic buffer diag =
      if buffer.current_size >= buffer.max_size then
        buffer (* Drop if over capacity - streaming backpressure *)
      else
        let () = match diag.Output.severity with
          | "error" -> Queue.add diag buffer.errors
          | "warning" -> Queue.add diag buffer.warnings
          | _ -> Queue.add diag buffer.warnings (* Default to warning queue *)
        in
        { buffer with current_size = buffer.current_size + 1 }
    
    let to_stream buffer =
      let errors_done = ref false in
      fun () ->
        if not !errors_done then
          match Queue.take_opt buffer.errors with
          | Some diag -> Some diag
          | None -> 
              errors_done := true;
              Queue.take_opt buffer.warnings
        else
          Queue.take_opt buffer.warnings
  end
  
  (* Streaming filter predicates *)
  let severity_predicate severity_filter =
    match severity_filter with
    | `All -> fun _ -> true
    | `Error -> fun d -> d.Output.severity = "error"
    | `Warning -> fun d -> d.Output.severity = "warning"
  
  let file_pattern_predicate file_pattern =
    fun d -> matches_file_pattern file_pattern d.Output.file
  
  (* Core streaming operations *)
  let filter_stream ~predicate stream =
    fun () ->
      let rec loop () =
        match stream () with
        | None -> None
        | Some item when predicate item -> Some item
        | Some _ -> loop () (* Skip non-matching, continue streaming *)
      in loop ()
  
  let take_while_under_token_limit ~token_limit ~metadata_tokens stream =
    let current_tokens = ref metadata_tokens in
    let count = ref 0 in
    fun () ->
      match stream () with
      | None -> None
      | Some diag ->
          let diag_tokens = estimate_diagnostic_tokens diag in
          let safe_tokens = int_of_float (float_of_int diag_tokens *. 1.4) in
          if !current_tokens + safe_tokens > token_limit then
            None (* Stop streaming when limit would be exceeded *)
          else (
            current_tokens := !current_tokens + safe_tokens;
            incr count;
            Some diag
          )
  
  let take_page ~page ~page_size stream =
    let skip_count = page * page_size in
    let take_count = page_size in
    let skipped = ref 0 in
    let taken = ref 0 in
    
    fun () ->
      let rec loop () =
        if !taken >= take_count then None
        else
          match stream () with
          | None -> None
          | Some _item when !skipped < skip_count ->
              incr skipped;
              loop ()
          | Some item ->
              incr taken;
              Some item
      in loop ()
  
  (* Convert list to stream for compatibility *)
  let of_list lst =
    let remaining = ref lst in
    fun () ->
      match !remaining with
      | [] -> None
      | hd :: tl ->
          remaining := tl;
          Some hd
  
  (* Collect stream to list with early termination *)
  let to_list ?(limit=max_int) stream =
    let rec loop acc count =
      if count >= limit then List.rev acc
      else
        match stream () with
        | None -> List.rev acc
        | Some item -> loop (item :: acc) (count + 1)
    in
    loop [] 0
end

(* Legacy filtering functions for compatibility *)
let filter_by_severity (severity_filter : [`Error | `Warning | `All]) (diagnostics : Output.diagnostic list) : Output.diagnostic list =
  match severity_filter with
  | `All -> diagnostics
  | `Error -> List.filter (fun d -> d.Output.severity = "error") diagnostics
  | `Warning -> List.filter (fun d -> d.Output.severity = "warning") diagnostics

let filter_by_file_pattern (file_pattern : string option) (diagnostics : Output.diagnostic list) : Output.diagnostic list =
  List.filter (fun d -> matches_file_pattern file_pattern d.Output.file) diagnostics

(* High-Performance Streaming Processor *)
module StreamingProcessor = struct
  type processing_result = {
    diagnostics: Output.diagnostic list;
    total_processed: int;
    truncated: bool;
    truncation_reason: string option;
    next_cursor: string option;
    estimated_tokens: int;
  }
  
  let process_diagnostics_stream 
      ~severity_filter 
      ~file_pattern 
      ~page 
      ~page_size 
      ~token_limit 
      ~metadata_tokens 
      (input_diagnostics: Output.diagnostic list) : processing_result =
    
    (* Step 1: Convert input to stream *)
    let base_stream = DiagnosticStream.of_list input_diagnostics in
    
    (* Step 2: Apply severity filter streaming *)
    let severity_predicate = DiagnosticStream.severity_predicate severity_filter in
    let filtered_stream = DiagnosticStream.filter_stream ~predicate:severity_predicate base_stream in
    
    (* Step 3: Apply file pattern filter streaming *)
    let file_predicate = DiagnosticStream.file_pattern_predicate file_pattern in
    let pattern_filtered_stream = DiagnosticStream.filter_stream ~predicate:file_predicate filtered_stream in
    
    (* Step 4: Priority sorting using streaming buffer *)
    let max_buffer_size = match page with
      | Some p -> (p + 1) * page_size + 100  (* Only buffer what we need for the page plus safety *)
      | None -> min 10000 (List.length input_diagnostics) (* Reasonable buffer limit *)
    in
    
    let priority_buffer = DiagnosticStream.PriorityBuffer.create max_buffer_size in
    
    (* Fill priority buffer from filtered stream *)
    let rec fill_buffer buffer =
      match pattern_filtered_stream () with
      | None -> buffer
      | Some diag -> fill_buffer (DiagnosticStream.PriorityBuffer.add_diagnostic buffer diag)
    in
    
    let filled_buffer = fill_buffer priority_buffer in
    let prioritized_stream = DiagnosticStream.PriorityBuffer.to_stream filled_buffer in
    
    (* Step 5: Apply pagination or token limits streaming *)
    let (final_stream, has_more, next_cursor, truncation_reason) = match page with
      | Some p ->
          (* Pagination mode: stream only the requested page *)
          let page_stream = DiagnosticStream.take_page ~page:p ~page_size prioritized_stream in
          (* Check if there are more items after this page *)
          let test_stream = DiagnosticStream.PriorityBuffer.to_stream filled_buffer in
          let total_available = DiagnosticStream.to_list ~limit:((p + 2) * page_size) test_stream |> List.length in
          let has_more_pages = total_available > (p + 1) * page_size in
          let next_cursor = if has_more_pages then Some (string_of_int (p + 1)) else None in
          let truncation_reason = if has_more_pages then 
            Some "Results paginated - use next_cursor to get more pages" 
          else None in
          (page_stream, has_more_pages, next_cursor, truncation_reason)
      | None ->
          (* Token limit mode: stream until token limit *)
          let token_limited_stream = DiagnosticStream.take_while_under_token_limit 
            ~token_limit ~metadata_tokens prioritized_stream in
          (* We don't know if there are more without consuming the stream, so check buffer size *)
          let buffer_full = filled_buffer.current_size >= filled_buffer.max_size in
          let truncation_reason = if buffer_full then 
            Some (Printf.sprintf "Results limited to %d diagnostics due to token constraints" filled_buffer.max_size)
          else None in
          (token_limited_stream, buffer_full, None, truncation_reason)
    in
    
    (* Step 6: Materialize final results with limit to prevent memory issues *)
    let final_diagnostics = DiagnosticStream.to_list ~limit:1000 final_stream in
    
    (* Step 7: Calculate actual tokens used *)
    let estimated_tokens = List.fold_left (fun acc d -> acc + estimate_diagnostic_tokens d) metadata_tokens final_diagnostics in
    
    {
      diagnostics = final_diagnostics;
      total_processed = filled_buffer.current_size;
      truncated = (match truncation_reason with Some _ -> true | None -> false) || has_more;
      truncation_reason;
      next_cursor;
      estimated_tokens;
    }
end

(* Legacy functions for compatibility *)
let apply_pagination (args : Args.t) (diagnostics : Output.diagnostic list) : 
  Output.diagnostic list * bool * string option * string option =
  match args.page with
  | None -> 
    (* No pagination requested, return all diagnostics *)
    (diagnostics, false, None, None)
  | Some page ->
    let page_size = match args.max_diagnostics with Some n -> n | None -> 50 in
    let start_index = page * page_size in
    let total_count = List.length diagnostics in
    
    if start_index >= total_count then
      (* Page exceeds available data *)
      ([], false, None, Some "Requested page exceeds available data")
    else
      let end_index = min (start_index + page_size) total_count in
      let page_diagnostics = 
        diagnostics 
        |> List.mapi (fun i d -> (i, d))
        |> List.filter (fun (i, _) -> i >= start_index && i < end_index)
        |> List.map (fun (_, d) -> d)
      in
      let has_more = end_index < total_count in
      let next_cursor = if has_more then Some (string_of_int (page + 1)) else None in
      let truncation_reason = 
        if has_more then Some "Results paginated - use next_cursor to get more pages" else None
      in
      (page_diagnostics, has_more, next_cursor, truncation_reason)

let filter_diagnostics_by_token_limit ~max_tokens:_ (diagnostics : Output.diagnostic list) :
    Output.diagnostic list * bool * string option =
  (* Use 20,000 token soft limit with 5,000 buffer for metadata and safety *)
  let soft_limit = 20000 in
  let metadata_estimate = 1000 in  (* Conservative estimate for all metadata *)
  let available_for_diagnostics = soft_limit - metadata_estimate in
  
  (* If no diagnostics, no truncation needed *)
  if diagnostics = [] then ([], false, None) else
  
  let rec filter_loop acc acc_tokens remaining count =
    match remaining with
    | [] -> (List.rev acc, false, None) (* No truncation needed *)
    | d :: rest ->
        let d_tokens = estimate_diagnostic_tokens d in
        (* Apply 1.4x safety multiplier for unknown tokenization variations *)
        let d_tokens_safe = int_of_float (float_of_int d_tokens *. 1.4) in
        let new_total = acc_tokens + d_tokens_safe in
        
        if new_total > available_for_diagnostics then
          (* Would exceed limit, truncate here *)
          let reason = Printf.sprintf 
            "Response truncated after %d diagnostics due to 25,000 token limit (estimated %d tokens used)" 
            count acc_tokens in
          (List.rev acc, true, Some reason)
        else
          filter_loop (d :: acc) new_total rest (count + 1)
  in
  
  filter_loop [] 0 diagnostics 0

let execute ~sw:_ ~env:_ (sdk : Ocaml_platform_sdk.t) (args : Args.t) =
  match Dune.diagnostics sdk ~file:"" with
  | Error `Dune_not_initialized -> Error Error.Dune_not_connected
  | Ok diagnostics -> (
      match Dune.progress sdk with
      | Error `Dune_not_initialized -> Error Error.Dune_not_connected
      | Ok progress ->
          let status =
            match progress with
            | Dune.Waiting -> "waiting"
            | Dune.In_progress { complete; remaining; failed } ->
                Printf.sprintf "building (%d/%d completed, %d failed)" complete
                  (complete + remaining) failed
            | Dune.Failed -> "failed"
            | Dune.Interrupted -> "interrupted"
            | Dune.Success ->
                if List.length diagnostics = 0 then "success"
                else "success_with_warnings"
          in

          let formatted_diagnostics =
            List.map
              (fun d ->
                let severity =
                  match d.Dune.severity with
                  | `Error -> "error"
                  | `Warning -> "warning"
                in
                {
                  Output.severity;
                  file = d.file;
                  line = d.line;
                  column = d.column;
                  message = d.message;
                })
              diagnostics
          in
          
          (* HIGH-PERFORMANCE STREAMING PROCESSING *)
          let metadata_estimate = 1000 in  (* Conservative estimate for response metadata *)
          let token_limit = 25000 in
          let page_size = match args.max_diagnostics with Some n -> n | None -> 50 in
          let severity_filter = match args.severity_filter with Some s -> s | None -> `All in
          
          (* Use streaming processor for maximum efficiency *)
          let processing_result = StreamingProcessor.process_diagnostics_stream
            ~severity_filter
            ~file_pattern:args.file_pattern
            ~page:args.page
            ~page_size
            ~token_limit
            ~metadata_tokens:metadata_estimate
            formatted_diagnostics
          in
          
          (* Count errors and warnings in original diagnostics for summary *)
          let total_error_count = List.length (List.filter (fun d -> d.Output.severity = "error") formatted_diagnostics) in
          let total_warning_count = List.length (List.filter (fun d -> d.Output.severity = "warning") formatted_diagnostics) in
          let total_count = List.length formatted_diagnostics in
          
          (* Create build summary based on progress *)
          let build_summary = 
            match progress with
            | Dune.In_progress { complete; remaining; failed } ->
                Some { Output.completed = complete; remaining; failed }
            | _ -> None
          in
          
          let summary = {
            Output.total_diagnostics = total_count;
            returned_diagnostics = List.length processing_result.diagnostics;
            error_count = total_error_count;
            warning_count = total_warning_count;
            build_summary;
          } in
          
          (* Create preliminary result to calculate actual token count *)
          let preliminary_result = {
            Output.status;
            diagnostics = processing_result.diagnostics;
            truncated = processing_result.truncated;
            truncation_reason = processing_result.truncation_reason;
            next_cursor = processing_result.next_cursor;
            token_count = 0; (* Will be calculated below *)
            summary;
          } in
          
          (* Calculate actual token count for the response *)
          let actual_token_count = estimate_response_tokens preliminary_result in
          
          (* Final result with accurate token count *)
          let result = { preliminary_result with token_count = actual_token_count } in

          Ok result)
