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
    cursor : string option;
    severity_filter : severity_filter option;
    file_pattern : string option;
  }
  
  (* JSON representation type for API contract *)
  module Json = struct
    type args_json = {
      targets : string list option [@default None];
      max_diagnostics : int option [@default None];
      cursor : string option [@default None];
      severity_filter : string option [@default None];
      file_pattern : string option [@default None];
    } [@@deriving yojson]
  end
  
  (* Parameter validation errors *)
  type validation_error = [
    | `Invalid_severity of string
    | `Invalid_max_diagnostics of int * string
    | `Invalid_cursor of string * string
    | `Invalid_file_pattern of string * string
  ]
  
  let string_of_validation_error = function
    | `Invalid_severity s -> 
        Printf.sprintf "Invalid severity '%s', expected: 'error', 'warning', or 'all'" s
    | `Invalid_max_diagnostics (v, reason) ->
        Printf.sprintf "Invalid max_diagnostics value %d: %s" v reason
    | `Invalid_cursor (cursor, reason) ->
        Printf.sprintf "Invalid cursor '%s': %s" cursor reason
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
    
    (* Validate cursor (must be valid base64 or numeric offset) *)
    let cursor_result = match json_args.cursor with
      | None -> Ok None
      | Some cursor -> 
          let cursor_len = String.length cursor in
          if cursor_len = 0 then
            Error (`Invalid_cursor (cursor, "cursor cannot be empty"))
          else if cursor_len > 100 then
            Error (`Invalid_cursor (cursor, "cursor too long (max 100 chars)"))
          else
            (* Simple validation: numeric offset or base64-like string *)
            try
              let _ = int_of_string cursor in
              Ok (Some cursor) (* Numeric cursor *)
            with Failure _ ->
              (* Validate as potential base64/token *)
              if Str.string_match (Str.regexp "^[a-zA-Z0-9+/=_-]+$") cursor 0 then
                Ok (Some cursor)
              else
                Error (`Invalid_cursor (cursor, "invalid cursor format"))
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
    match severity_filter_result, max_diagnostics_result, cursor_result, file_pattern_result with
    | Ok severity_filter, Ok max_diagnostics, Ok cursor, Ok file_pattern ->
        Ok {
          targets = json_args.targets;
          max_diagnostics;
          cursor;
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
      cursor = args.cursor;
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
    cursor = None;
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
              ( "cursor",
                `Assoc
                  [
                    ("type", `String "string");
                    ("description", `String "Cursor for paginated results (opaque token from previous response)");
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

(* Re-export shared types *)
module Output = Build_types.Output

module Error = struct
  type t = Dune_not_connected

  let to_string = function
    | Dune_not_connected ->
        "Dune RPC not connected. Please run this command from a dune project."
end


(* Re-export file pattern matching from File_utils *)
let matches_file_pattern = File_utils.matches_file_pattern



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
      ~cursor 
      ~page_size 
      ~token_limit 
      ~metadata_tokens 
      (input_diagnostics: Output.diagnostic list) : processing_result =
    
    (* Step 1: Convert input to stream *)
    let base_stream = Diagnostic_stream.of_list input_diagnostics in
    
    (* Step 2: Apply severity filter streaming *)
    let severity_predicate = Diagnostic_stream.severity_predicate severity_filter in
    let filtered_stream = Diagnostic_stream.filter_stream ~predicate:severity_predicate base_stream in
    
    (* Step 3: Apply file pattern filter streaming *)
    let file_predicate = Diagnostic_stream.file_pattern_predicate file_pattern in
    let pattern_filtered_stream = Diagnostic_stream.filter_stream ~predicate:file_predicate filtered_stream in
    
    (* Step 4: Priority sorting using streaming buffer *)
    let max_buffer_size = match cursor with
      | Some c -> 
          (* Parse cursor to estimate buffer size needed *)
          (try
            let offset = int_of_string c in
            let requested_buffer = offset + page_size + 100 in
            min 10000 requested_buffer  (* Never exceed 10,000 diagnostics in memory *)
          with Failure _ ->
            min 5000 (List.length input_diagnostics) (* Conservative for non-numeric cursors *)
          )
      | None -> min 10000 (List.length input_diagnostics) (* Reasonable buffer limit *)
    in
    
    let priority_buffer = Diagnostic_stream.PriorityBuffer.create max_buffer_size in
    
    (* Fill priority buffer from filtered stream *)
    let rec fill_buffer buffer =
      match pattern_filtered_stream () with
      | None -> buffer
      | Some diag -> fill_buffer (Diagnostic_stream.PriorityBuffer.add_diagnostic buffer diag)
    in
    
    let filled_buffer = fill_buffer priority_buffer in
    let prioritized_stream = Diagnostic_stream.PriorityBuffer.to_stream filled_buffer in
    
    (* Step 5: Apply cursor-based pagination or token limits *)
    let (final_stream, has_more, next_cursor, truncation_reason) = match cursor with
      | Some cursor_str ->
          (* Cursor-based pagination: parse cursor and skip to offset *)
          let offset = try int_of_string cursor_str with Failure _ -> 0 in
          let cursor_stream = Diagnostic_stream.skip_take ~skip:offset ~take:page_size prioritized_stream in
          
          (* Check if there are more items after this batch *)
          let test_stream = Diagnostic_stream.PriorityBuffer.to_stream filled_buffer in
          let total_available = Diagnostic_stream.to_list ~limit:(offset + page_size + 1) test_stream |> List.length in
          let has_more_items = total_available > (offset + page_size) in
          let next_cursor = if has_more_items then Some (string_of_int (offset + page_size)) else None in
          let truncation_reason = if has_more_items then 
            Some "Results paginated - use next_cursor to get more pages" 
          else None in
          (cursor_stream, has_more_items, next_cursor, truncation_reason)
      | None ->
          (* Token limit mode: stream until token limit *)
          let token_limited_stream = Diagnostic_stream.take_while_under_token_limit 
            ~token_limit ~metadata_tokens prioritized_stream in
          (* Check if more diagnostics available *)
          let limited_results = Diagnostic_stream.to_list ~limit:page_size token_limited_stream in
          let has_more_results = List.length limited_results >= page_size in
          let next_cursor = if has_more_results then Some (string_of_int page_size) else None in
          let truncation_reason = if has_more_results then 
            Some "Results limited by token constraints - use next_cursor to get more pages"
          else None in
          (Diagnostic_stream.of_list limited_results, has_more_results, next_cursor, truncation_reason)
    in
    
    (* Step 6: Materialize final results with limit to prevent memory issues *)
    let final_diagnostics = Diagnostic_stream.to_list ~limit:1000 final_stream in
    
    (* Step 7: Calculate actual tokens used *)
    let estimated_tokens = List.fold_left (fun acc d -> acc + Token_counting.estimate_diagnostic_tokens d) metadata_tokens final_diagnostics in
    
    {
      diagnostics = final_diagnostics;
      total_processed = Diagnostic_stream.PriorityBuffer.current_size filled_buffer;
      truncated = (match truncation_reason with Some _ -> true | None -> false) || has_more;
      truncation_reason;
      next_cursor;
      estimated_tokens;
    }
end


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
            ~cursor:args.cursor
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
          let actual_token_count = Token_counting.estimate_response_tokens preliminary_result in
          
          (* Final result with accurate token count *)
          let result = { preliminary_result with token_count = actual_token_count } in

          Ok result)
