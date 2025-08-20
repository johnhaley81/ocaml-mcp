(** Common types used by build status functionality.
    
    This module contains the shared type definitions to avoid circular dependencies. *)

module Output : sig
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
    build_summary : build_summary option;
  }
  [@@deriving yojson]

  type t = { 
    status : string; 
    diagnostics : diagnostic list;
    truncated : bool;
    truncation_reason : string option;
    next_cursor : string option;
    token_count : int;
    summary : diagnostic_summary;
  }
  [@@deriving yojson]
end