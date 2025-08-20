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

(** {1 Utility Modules} *)

module Token_counting : module type of Token_counting
module Build_types : module type of Build_types  
module Diagnostic_stream : module type of Diagnostic_stream
module File_utils : module type of File_utils


