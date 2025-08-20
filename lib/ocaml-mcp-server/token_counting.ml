(** Token counting system for build status responses.

    This module provides empirically-validated token counting for various
    text patterns commonly found in OCaml/Dune build outputs. *)

(* Helper function for List.split_n - splits list into first n elements and rest *)
let split_n n lst =
  let rec aux acc n = function
    | [] -> (List.rev acc, [])
    | hd :: tl when n > 0 -> aux (hd :: acc) (n - 1) tl
    | rest -> (List.rev acc, rest)
  in
  aux [] n lst

(* LRU Cache for token estimates to improve performance *)
module TokenCache = struct
  type cache_entry = {
    value: int;
    mutable access_time: float;
  }
  
  let cache : (string, cache_entry) Hashtbl.t = Hashtbl.create 1024
  let max_size = 2048
  let access_counter = ref 0.0
  
  let incr_access_counter () =
    access_counter := !access_counter +. 1.0
    
  let get_access_time () =
    incr_access_counter ();
    !access_counter
  
  let evict_lru_entries () =
    let entries = Hashtbl.fold (fun key entry acc -> (key, entry) :: acc) cache [] in
    let sorted_entries = List.sort (fun (_, e1) (_, e2) -> 
      Float.compare e1.access_time e2.access_time) entries in
    let to_remove = max 1 (List.length sorted_entries / 4) in (* Remove 25% of oldest entries *)
    let (remove_list, _) = split_n to_remove sorted_entries in
    List.iter (fun (key, _) -> Hashtbl.remove cache key) remove_list
  
  let get_or_compute key compute_fn =
    match Hashtbl.find_opt cache key with
    | Some entry ->
        entry.access_time <- get_access_time ();
        entry.value
    | None ->
        let value = compute_fn () in
        if Hashtbl.length cache >= max_size then
          evict_lru_entries ();
        let entry = { value; access_time = get_access_time () } in
        Hashtbl.replace cache key entry;
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
let estimate_diagnostic_tokens (d : Build_types.Output.diagnostic) : int =
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
let estimate_response_tokens (output : Build_types.Output.t) : int =
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
      (if s.total_diagnostics < 100 then 1 else if s.total_diagnostics < 10000 then 2 else 3) +
      estimate_json_field_overhead "total_diagnostics" `Number +
      (if s.returned_diagnostics < 100 then 1 else if s.returned_diagnostics < 10000 then 2 else 3) +
      estimate_json_field_overhead "returned_diagnostics" `Number +
      (if s.error_count < 100 then 1 else if s.error_count < 1000 then 2 else 3) +
      estimate_json_field_overhead "error_count" `Number +
      (if s.warning_count < 100 then 1 else if s.warning_count < 1000 then 2 else 3) +
      estimate_json_field_overhead "warning_count" `Number
    in
    let build_summary_tokens = 
      match s.build_summary with
      | None -> 1 + estimate_json_field_overhead "build_summary" `Object  (* null value *)
      | Some bs -> 
          (* Build summary nested object *)
          let completed_tokens = (if bs.completed < 100 then 1 else 2) +
                                 estimate_json_field_overhead "completed" `Number in
          let remaining_tokens = (if bs.remaining < 100 then 1 else 2) +
                                estimate_json_field_overhead "remaining" `Number in
          let failed_tokens = (if bs.failed < 100 then 1 else 2) +
                             estimate_json_field_overhead "failed" `Number in
          completed_tokens + remaining_tokens + failed_tokens + 
          estimate_json_field_overhead "build_summary" `Object + 3  (* Nested object overhead *)
    in
    basic_fields_tokens + build_summary_tokens +
    estimate_json_field_overhead "summary" `Object + 3  (* Summary object structure *)
  in
  
  (* Main response object structure overhead *)
  let main_object_overhead = 10 in  (* Root object braces, commas, etc. *)
  
  diagnostics_tokens + diagnostics_array_overhead + status_tokens + truncated_tokens + 
  truncation_reason_tokens + next_cursor_tokens + token_count_tokens + 
  summary_tokens + main_object_overhead