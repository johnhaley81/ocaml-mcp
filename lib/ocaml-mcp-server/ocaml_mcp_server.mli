(** OCaml MCP Server.

    This server provides OCaml development tools through the Model Context
    Protocol, integrating with Dune build system for code intelligence.

    {1 Configuration} *)

type config = {
  project_root : string option;
      (** Project root directory. Auto-detected if None. *)
  enable_dune : bool;  (** Enable Dune RPC for build status and diagnostics. *)
  enable_mcp_logging : bool;  (** Enable MCP protocol logging. *)
  mcp_log_level : Mcp.Types.LogLevel.t option;  (** Initial MCP log level. *)
}

val default_config : config
(** [default_config] enables all features with auto-detected project root. *)

(** {1 Server Creation} *)

val create_server :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  config:config ->
  Mcp_sdk_eio.Server.t
(** [create_server ~sw ~env ~config] creates async MCP server using the SDK.

    Initializes Dune RPC polling based on config. *)

val run_stdio : env:Eio_unix.Stdenv.base -> config:config -> unit
(** [run_stdio ~env ~config] runs server on stdin/stdout. *)

val run :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  connection:Mcp_eio.Connection.t ->
  config:config ->
  unit
(** [run ~sw ~env ~connection ~config] runs server on provided connection. *)

(** {1 Tools} *)

module type S = sig
  val name : string
  val description : string

  module Args : sig
    type t

    val of_yojson : Yojson.Safe.t -> (t, string) Result.t
    val to_yojson : t -> Yojson.Safe.t
    val schema : unit -> Yojson.Safe.t
  end

  module Output : sig
    type t

    val to_yojson : t -> Yojson.Safe.t
  end

  module Error : sig
    type t

    val to_string : t -> string
  end

  val execute :
    sw:Eio.Switch.t ->
    env:Eio_unix.Stdenv.base ->
    Ocaml_platform_sdk.t ->
    Args.t ->
    (Output.t, Error.t) Result.t
end

val build_status : (module S)
val build_target : (module S)
val eval : (module S)
val find_definition : (module S)
val find_references : (module S)
val fs_edit : (module S)
val fs_read : (module S)
val fs_write : (module S)
val module_signature : (module S)
val project_structure : (module S)
val run_tests : (module S)
val type_at_pos : (module S)

(** {1 Module Access} *)

module Tools : sig
  module Build_status : S
  module Build_target : S
  module Eval : S
  module Find_definition : S
  module Find_references : S
  module Fs_edit : S
  module Fs_read : S
  module Fs_write : S
  module Module_signature : S
  module Project_structure : S
  module Run_tests : S
  module Type_at_pos : S
end

(** {1 Testing Support} *)

(** Internal types exposed for testing purposes only.
    These should not be used in production code. *)
module Testing : sig
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
end
