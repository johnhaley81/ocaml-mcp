(** File pattern matching utilities.
    
    This module provides secure file pattern matching functionality
    to avoid circular dependencies. *)

[@@@warning "-69"] (* Suppress unused field warning for complexity_score *)

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