(** Testing support module for ocaml-mcp-server.

    This module provides internal types and functions exposed for testing purposes only.
    These should not be used in production code. *)

module Build_status : sig
  module Args : sig
    type severity_filter = [`Error | `Warning | `All]
    
    type t = {
      targets : string list option;
      max_diagnostics : int option;
      page : int option;
      severity_filter : severity_filter option;
      file_pattern : string option;
    }

    val of_yojson : Yojson.Safe.t -> (t, string) Result.t
    val to_yojson : t -> Yojson.Safe.t
  end

  module Output : sig
    type diagnostic = {
      severity : string;
      file : string;
      line : int;
      column : int;
      message : string;
    }
    
    type build_summary = {
      completed : int;
      remaining : int;
      failed : int;
    }
    
    type diagnostic_summary = {
      total_diagnostics : int;
      returned_diagnostics : int;
      error_count : int;
      warning_count : int;
      build_summary : build_summary option;
    }
    
    type t = {
      status : string;
      diagnostics : diagnostic list;
      truncated : bool;
      truncation_reason : string option;
      next_cursor : string option;
      token_count : int;
      summary : diagnostic_summary;
    }

    val to_yojson : t -> Yojson.Safe.t
    val diagnostic_of_yojson : Yojson.Safe.t -> (diagnostic, string) Result.t
  end
end