(** A programmatic interface to OCaml Platform tools.

    This SDK provides a unified, type-safe API for interacting with core OCaml
    development tools like Dune, Merlin, and OCamlformat.

    The main entry point is the {!t} type, which represents an active session
    for a specific project. It must be created and used within an Eio event
    loop.

    {[
      Eio_main.run @@ fun env ->
      Eio.Switch.run @@ fun sw ->
      let sdk = Ocaml_platform_sdk.create ~sw ~env ~project_root:"." () in
      (* ... use the sdk ... *)
      Ocaml_platform_sdk.close sdk
    ]} *)

(** {1 Session Management} *)

type t
(** The main SDK session handle. It encapsulates clients for all platform tools
    and must be used within an Eio context. *)

val create :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  project_root:string ->
  ?enable_dune:bool ->
  unit ->
  t
(** [create ~sw ~env ~project_root ()] initializes a new SDK session for the
    project at [project_root].

    This function sets up clients for Merlin and OCamlformat. If [enable_dune]
    is true (the default), it also starts a background fiber to poll for and
    connect to a Dune RPC server.

    @param sw The Eio switch to manage background fibers (e.g., Dune RPC).
    @param env The Eio environment.
    @param project_root The root directory of the OCaml project.
    @param enable_dune
      Defaults to [true]. If false, the Dune RPC client will not be initialized.
*)

val close : t -> unit
(** [close t] gracefully shuts down the session and releases resources, such as
    disconnecting from the Dune RPC server. *)

(** {1 Dune Integration} *)
module Dune : sig
  type diagnostic = Dune_rpc_client.diagnostic = {
    file : string;
    line : int;
    column : int;
    message : string;
    severity : [ `Error | `Warning ];
  }
  (** A diagnostic message (error or warning) from Dune. *)

  type progress = Dune_rpc_client.progress =
    | Waiting
    | In_progress of { complete : int; remaining : int; failed : int }
    | Failed
    | Interrupted
    | Success  (** The current build progress reported by Dune. *)

  val diagnostics :
    t -> file:string -> (diagnostic list, [> `Dune_not_initialized ]) result
  (** [diagnostics t ~file] gets the current list of diagnostics from Dune. If
      [file] is an empty string, it returns all diagnostics for the project.
      Returns an error if the Dune client was not initialized. *)

  val progress : t -> (progress, [> `Dune_not_initialized ]) result
  (** [progress t] gets the current build progress from Dune. Returns an error
      if the Dune client was not initialized. *)

  (** {2 Structured Project Information} *)

  (** This module contains types that represent the output of `dune describe`,
      providing a structured view of the project's libraries, executables, and
      modules. *)
  module Describe : sig
    type uid = string
    (** A unique identifier for a library, as produced by Dune. This is used to
        link dependencies. *)

    type module_deps = {
      for_intf : string list;  (** Modules required by the .mli file. *)
      for_impl : string list;  (** Modules required by the .ml file. *)
    }
    (** Information about a module's dependencies on other modules. *)

    type module_ = {
      name : string;
      impl : string option;  (** Path to the .ml file, if it exists. *)
      intf : string option;  (** Path to the .mli file, if it exists. *)
      module_deps : module_deps option;
    }
    (** A single OCaml module within a library or executable. *)

    type executable = {
      names : string list;
      requires : uid list;
          (** List of library UIDs this executable depends on. *)
      modules : module_ list;
    }
    (** An executable or a group of executables defined in the project. *)

    type library = {
      name : string;
      uid : uid;
      requires : uid list;  (** List of library UIDs this library depends on. *)
      local : bool;  (** True if the library is part of the local project. *)
      modules : module_ list;
    }
    (** A library defined in the project. *)

    (** An entry in the `dune describe` output. This is a sum type representing
        the different kinds of stanzas in a project. *)
    type entry =
      | Library of library
      | Executables of executable
      | Other of Sexplib.Sexp.t
          (** A catch-all for other or future entry types from `dune describe`,
              ensuring forward compatibility. *)

    type t = entry list
    (** The complete, structured output of `dune describe`. *)
  end

  val describe : t -> (Describe.t, [> `Msg of string ]) result
  (** [describe t] runs `dune describe` and parses the output into a structured
      representation. This is the primary input for building a project-level
      dependency graph or performing other whole-project analyses. *)

  (** {2 Command-Line Interaction} *)

  val run : t -> args:string list -> (string, [> `Msg of string ]) result
  (** [run t ~args] executes a `dune` command with the given arguments in the
      project root and returns its standard output. Example: `Dune.run t
      ~args:["build"; "@install"]` *)

  (** {2 Build Artifacts} *)

  val find_cm_file :
    t ->
    module_path:string list ->
    extension:string ->
    (string option, [> `Msg of string ]) result
  (** [find_cm_file t ~module_path ~extension] finds a compiled module file
      (e.g., .cmi, .cmt) in the project's `_build` directory.

      @param module_path A path like `["My_lib"; "Utils"]`.
      @param extension The file extension, e.g., `".cmi"`. *)
end

(** {1 Merlin Integration} *)
module Merlin : sig
  val find_definition :
    t ->
    source_path:string ->
    source_text:string ->
    line:int ->
    col:int ->
    (string * Lexing.position, string) result
  (** [find_definition t ~source_path ~source_text ~line ~col] locates the
      definition of the symbol at the given position. *)

  val find_references :
    t ->
    source_path:string ->
    source_text:string ->
    line:int ->
    col:int ->
    ((Ocaml_utils.Warnings.loc * string) list, string) result
  (** [find_references t ~source_path ~source_text ~line ~col] finds all
      references to the symbol at the given position. *)

  val type_at_pos :
    t ->
    source_path:string ->
    source_text:string ->
    line:int ->
    col:int ->
    (Ocaml_utils.Warnings.loc * string, string) result
  (** [type_at_pos t ~source_path ~source_text ~line ~col] gets the type of the
      expression at the given position. *)

  val document_symbols :
    t ->
    source_path:string ->
    source_text:string ->
    (Query_protocol.item list, string) result
  (** [document_symbols t ~source_path ~source_text] returns the outline (e.g.,
      values, types, modules) of the given source file. *)

  val diagnostics :
    t ->
    source_path:string ->
    source_text:string ->
    (Ocaml_parsing.Location.report list, string) result
  (** [diagnostics t ~source_path ~source_text] gets syntax and type errors from
      Merlin for the given source file. *)
end

(** {1 OCamlformat Integration} *)
module Ocamlformat : sig
  val format_doc : t -> path:string -> content:string -> (string, string) result
  (** [format_doc t ~path ~content] formats an OCaml source file. It
      automatically detects whether it is an implementation (.ml) or interface
      (.mli). *)

  val format_type : t -> typ:string -> (string, [> `Msg of string ]) result
  (** [format_type t ~typ] formats a string containing an OCaml type expression.
  *)
end

(** {1 Code Analysis} *)
module Analysis : sig
  val module_signature : t -> module_path:string list -> (string, string) result
  (** [module_signature t ~module_path] reads the build artifacts (.cmi or .cmt)
      to extract the signature of a compiled module. Example:
      [module_signature t ~module_path:["My_lib"; "Utils"]] *)
end
