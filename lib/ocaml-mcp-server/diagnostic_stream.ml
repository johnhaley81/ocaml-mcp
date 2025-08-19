(** High-Performance Streaming Diagnostic Processor for build status results.

    This module provides efficient stream processing for diagnostic data,
    including priority-based sorting, filtering, and pagination. *)

type 'a stream = unit -> 'a option

(* Priority queue implementation for error-first sorting *)
module PriorityBuffer = struct
  type t = {
    errors: Build_types.Output.diagnostic Queue.t;
    warnings: Build_types.Output.diagnostic Queue.t;
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
      let () = match diag.Build_types.Output.severity with
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
  
  let current_size buffer = buffer.current_size
  
  let max_size buffer = buffer.max_size
end

(* Streaming filter predicates *)
let severity_predicate severity_filter =
  match severity_filter with
  | `All -> fun _ -> true
  | `Error -> fun d -> d.Build_types.Output.severity = "error"
  | `Warning -> fun d -> d.Build_types.Output.severity = "warning"

let file_pattern_predicate file_pattern =
  fun d -> File_utils.matches_file_pattern file_pattern d.Build_types.Output.file

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
        let diag_tokens = Token_counting.estimate_diagnostic_tokens diag in
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