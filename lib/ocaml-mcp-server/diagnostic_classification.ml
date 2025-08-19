(** Diagnostic classification and filtering functionality.

    This module provides functions for filtering and classifying diagnostics
    based on severity levels and file patterns. *)

(** Filter diagnostics by severity level *)
let filter_by_severity (severity_filter : [`Error | `Warning | `All]) (diagnostics : Build_types.Output.diagnostic list) : Build_types.Output.diagnostic list =
  match severity_filter with
  | `All -> diagnostics
  | `Error -> List.filter (fun d -> d.Build_types.Output.severity = "error") diagnostics
  | `Warning -> List.filter (fun d -> d.Build_types.Output.severity = "warning") diagnostics

(** Filter diagnostics by file pattern *)
let filter_by_file_pattern (file_pattern : string option) (diagnostics : Build_types.Output.diagnostic list) : Build_types.Output.diagnostic list =
  List.filter (fun d -> File_utils.matches_file_pattern file_pattern d.Build_types.Output.file) diagnostics

(** Check if a diagnostic is an error *)
let is_error (diagnostic : Build_types.Output.diagnostic) : bool =
  diagnostic.severity = "error"

(** Check if a diagnostic is a warning *)  
let is_warning (diagnostic : Build_types.Output.diagnostic) : bool =
  diagnostic.severity = "warning"

(** Count diagnostics by severity *)
let count_by_severity (diagnostics : Build_types.Output.diagnostic list) : int * int =
  List.fold_left (fun (errors, warnings) d ->
    match d.Build_types.Output.severity with
    | "error" -> (errors + 1, warnings)
    | "warning" -> (errors, warnings + 1)
    | _ -> (errors, warnings)
  ) (0, 0) diagnostics