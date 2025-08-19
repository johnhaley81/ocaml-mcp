(** Diagnostic classification and filtering functionality.

    This module provides functions for filtering and classifying diagnostics
    based on severity levels and file patterns. *)

val filter_by_severity : [`Error | `Warning | `All] -> Build_types.Output.diagnostic list -> Build_types.Output.diagnostic list
(** [filter_by_severity filter diagnostics] filters diagnostics by severity level *)

val filter_by_file_pattern : string option -> Build_types.Output.diagnostic list -> Build_types.Output.diagnostic list
(** [filter_by_file_pattern pattern diagnostics] filters diagnostics by file pattern *)

val is_error : Build_types.Output.diagnostic -> bool
(** [is_error diagnostic] checks if diagnostic is an error *)

val is_warning : Build_types.Output.diagnostic -> bool
(** [is_warning diagnostic] checks if diagnostic is a warning *)

val count_by_severity : Build_types.Output.diagnostic list -> int * int
(** [count_by_severity diagnostics] returns (error_count, warning_count) *)