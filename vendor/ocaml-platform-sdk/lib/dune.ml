type diagnostic = Dune_rpc_client.diagnostic = {
  file : string;
  line : int;
  column : int;
  message : string;
  severity : [ `Error | `Warning ];
}

type progress = Dune_rpc_client.progress =
  | Waiting
  | In_progress of { complete : int; remaining : int; failed : int }
  | Failed
  | Interrupted
  | Success

module Describe = struct
  (* Directly use the types from the Dune_describe library *)
  type uid = Dune_describe.Digest.t

  type module_deps = Dune_describe.module_deps = {
    for_intf : string list;
    for_impl : string list;
  }

  (* We can redefine module_ here if we want to add the 'intf' field *)
  type module_ = Dune_describe.module_ = {
    name : string;
    impl : string option;
    intf : string option;
    module_deps : module_deps option;
  }

  type executable = Dune_describe.executable = {
    names : string list;
    requires : uid list;
    modules : Dune_describe.module_ list; (* Should be our new module_ type *)
  }

  type library = Dune_describe.library = {
    name : string;
    uid : uid;
    requires : uid list;
    local : bool;
    modules : Dune_describe.module_ list; (* Should be our new module_ type *)
  }

  type entry =
    | Library of library
    | Executables of executable
    | Other of Sexplib.Sexp.t

  type t = entry list

  (* Custom converter for a single entry. This makes our parsing robust
     against new entry types from Dune. *)
  let entry_of_sexp : Sexplib.Sexp.t -> entry = function
    | Sexplib.Sexp.List (Sexplib.Sexp.Atom "library" :: _ as sexp) ->
        Library (Dune_describe.library_of_sexp (Sexplib.Sexp.List sexp))
    | Sexplib.Sexp.List (Sexplib.Sexp.Atom "executables" :: _ as sexp) ->
        Executables (Dune_describe.executable_of_sexp (Sexplib.Sexp.List sexp))
    | sexp -> Other sexp

  let t_of_sexp (sexp : Sexplib.Sexp.t) : t =
    let open Sexplib.Conv in
    list_of_sexp entry_of_sexp sexp
end

let run_process t ~args =
  try
    let cmd = "dune" :: args in
    let proc_mgr = Eio.Stdenv.process_mgr t.Env.env in
    let cwd = Eio.Path.(Eio.Stdenv.fs t.Env.env / t.Env.project_root) in
    let output_buf = Buffer.create 1024 in
    Eio.Process.run proc_mgr ~cwd cmd ~stdout:(Eio.Flow.buffer_sink output_buf);
    let output = Buffer.contents output_buf in
    Ok output
  with
  | Eio.Exn.Io (Eio.Process.E (Eio.Process.Child_error code), _) ->
      let exit_code = match code with `Exited n -> n | `Signaled n -> -n in
      Error
        (`Msg
           (Printf.sprintf "Command `dune %s` failed with exit code %d"
              (String.concat " " args) exit_code))
  | exn ->
      Error
        (`Msg (Printf.sprintf "Failed to run dune: %s" (Printexc.to_string exn)))

let diagnostics t ~file =
  match t.Env.dune_rpc with
  | Some client -> Ok (Dune_rpc_client.get_diagnostics client ~file)
  | None -> Error `Dune_not_initialized

let progress t =
  match t.Env.dune_rpc with
  | Some client -> Ok (Dune_rpc_client.get_progress client)
  | None -> Error `Dune_not_initialized

let describe t =
  match run_process t ~args:[ "describe"; "--format=sexp" ] with
  | Error _ as e -> e
  | Ok output -> (
      try
        let describe_data =
          Parsexp.Conv_single.parse_string_exn output Describe.t_of_sexp
        in
        Ok describe_data
      with
      | Sexplib.Conv.Of_sexp_error (exn, sexp) ->
          let msg = Printexc.to_string exn in
          let sexp_str = Sexplib.Sexp.to_string_hum sexp in
          Error
            (`Msg
               (Printf.sprintf "Sexp conversion error: %s on sexp: %s" msg
                  sexp_str))
      | exn ->
          Error
            (`Msg
               (Printf.sprintf "Unexpected error during parsing: %s"
                  (Printexc.to_string exn))))

let run t ~args = run_process t ~args

let find_cm_file t ~module_path ~extension =
  let open Eio.Path in
  let fs = Eio.Stdenv.fs t.Env.env in
  let project_root = fs / t.Env.project_root in
  let build_dir = project_root / "_build" / "default" in
  let build_dir_str = t.Env.project_root ^ "/_build/default" in

  try
    let module_path_str = String.concat "." module_path in
    let filename = String.lowercase_ascii module_path_str ^ extension in

    (* Simple case: module is at the top level of a library *)
    let lib_path = List.rev module_path |> List.tl |> List.rev in
    let lib_dir_name = String.concat "." lib_path in
    let direct_path, direct_path_str =
      if lib_dir_name = "" then
        (build_dir / filename, build_dir_str ^ "/" ^ filename)
      else
        let objs_dir = List.hd (List.rev module_path) ^ ".objs" in
        ( build_dir / lib_dir_name / objs_dir / filename,
          build_dir_str ^ "/" ^ lib_dir_name ^ "/" ^ objs_dir ^ "/" ^ filename
        )
    in

    if Eio.Path.is_file direct_path then Ok (Some direct_path_str)
    else
      (* Fallback: search recursively (can be slow, should be improved with more
         knowledge of dune's layout scheme if possible) *)
      let rec search dir path_str =
        match Eio.Path.read_dir dir with
        | entries -> (
            let found = List.find_opt (fun name -> name = filename) entries in
            match found with
            | Some f -> Some (path_str ^ "/" ^ f)
            | None ->
                List.find_map
                  (fun name ->
                    let path = dir / name in
                    let new_path_str = path_str ^ "/" ^ name in
                    if Eio.Path.is_directory path then search path new_path_str
                    else None)
                  entries)
        | exception _ -> None
      in
      Ok (search build_dir build_dir_str)
  with exn ->
    Error
      (`Msg (Printf.sprintf "Error finding file: %s" (Printexc.to_string exn)))
