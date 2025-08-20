(** File pattern matching utilities.
    
    This module provides secure file pattern matching functionality. *)

val matches_glob_pattern : string -> string -> bool
(** [matches_glob_pattern pattern text] matches text against glob pattern *)

val matches_file_pattern : string option -> string -> bool
(** [matches_file_pattern pattern filepath] matches filepath against optional file pattern *)