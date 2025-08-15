let name = "ocaml_project_structure"
let description = "Return project layout, libraries, executables"

module Args = struct
  type t = unit

  (* Custom JSON handling for unit type - accept empty object {} *)
  let of_yojson = function
    | `Assoc [] -> Ok ()
    | `Assoc _ -> Ok ()  (* Accept any object, ignore fields *)
    | `Null -> Ok ()     (* Also accept null *)
    | json -> Error (Printf.sprintf "Expected object or null, got: %s" 
                      (Yojson.Safe.to_string json))

  let to_yojson () = `Assoc []

  let schema () =
    `Assoc
      [
        ("type", `String "object");
        ("properties", `Assoc []);
        ("required", `List []);
        ("additionalProperties", `Bool false);
      ]
end

module Output = struct
  type component_type = Library | Executable [@@deriving yojson]

  type component = {
    component_type : component_type;
    name : string;
    directory : string;
    source_dir : string;
    public_name : string option; [@yojson.option]
    modules : string list;
    dependencies : string list;
  }
  [@@deriving yojson]

  type debug_info = {
    command : string;
    working_directory : string;
    environment : string;
    process_success : bool;
    exit_code : int option;
    stdout_lines : int;
    stderr_lines : int;
  }
  [@@deriving yojson]

  type t = {
    project_root : string;
    build_context : string;
    components : component list;
    debug_info : debug_info option; [@yojson.option]
  }
  [@@deriving yojson]
end

module Error = struct
  type t = Dune_describe_failed of string | Parse_error of string

  let to_string = function
    | Dune_describe_failed msg -> Printf.sprintf "Dune describe failed: %s" msg
    | Parse_error msg -> Printf.sprintf "Failed to parse dune output: %s" msg
end

let src = Logs.Src.create "project-structure" ~doc:"Project structure tool"

module Log = (val Logs.src_log src : Logs.LOG)

(* Parse s-expression atom *)
let parse_atom = function
  | Csexp.Atom s -> s
  | List _ -> failwith "Expected atom, got list"

(* Parse s-expression list *)
let parse_list f = function Csexp.List l -> List.map f l | _ -> []

(* Find a field in an association list *)
let find_field name fields =
  List.find_opt
    (function
      | Csexp.List [ Csexp.Atom n; _ ] when n = name -> true | _ -> false)
    fields
  |> Option.map (function
       | Csexp.List [ _; value ] -> value
       | _ -> failwith "Invalid field")

(* Extract the first atom from a list field, with a default *)
let field_atom name default fields =
  match find_field name fields with
  | Some (Csexp.Atom s) -> s
  | Some (Csexp.List [ Csexp.Atom s ]) -> s
  | _ -> default

(* Extract the list from a field *)
let field_list name fields =
  match find_field name fields with Some (Csexp.List l) -> l | _ -> []

(* Extract modules from source tree *)
let rec extract_modules = function
  | Csexp.List [ Csexp.Atom "Group"; _; Csexp.List children ] ->
      List.concat_map extract_modules children
  | Csexp.List [ Csexp.Atom "Module"; Csexp.List fields; _ ] ->
      field_list "name" fields |> List.map parse_atom
  | _ -> []

(* Check if a component is a library *)
let is_library stanza_fields =
  List.exists
    (function Csexp.List [ Csexp.Atom "library"; _ ] -> true | _ -> false)
    stanza_fields

(* Check if a component is an executable *)
let is_executable stanza_fields =
  List.exists
    (function
      | Csexp.List [ Csexp.Atom "executables"; _ ] -> true
      | Csexp.List [ Csexp.Atom "executable"; _ ] -> true
      | _ -> false)
    stanza_fields

(* Extract dependencies *)
let extract_deps dep_list =
  List.filter_map
    (function
      | Csexp.Atom s when String.length s > 0 && s.[0] <> ':' -> Some s
      | _ -> None)
    dep_list

(* Extract library info from stanza *)
let extract_library_info stanza_data source_tree =
  let name = field_atom "name" "" stanza_data in
  let public_name =
    match find_field "public_name" stanza_data with
    | Some (Atom s) -> Some s
    | _ -> None
  in
  let deps = field_list "requires" stanza_data |> extract_deps in
  let modules = extract_modules source_tree in
  (name, public_name, deps, modules)

(* Extract executable info from stanza *)
let extract_executable_info stanza_data source_tree =
  let names = field_list "names" stanza_data |> List.map parse_atom in
  let public_names =
    field_list "public_names" stanza_data
    |> List.map (function Csexp.Atom s -> Some s | _ -> None)
  in
  let deps = field_list "requires" stanza_data |> extract_deps in
  let modules = extract_modules source_tree in
  List.map2 (fun n pn -> (n, pn, deps, modules)) names public_names

(* Parse component from dune describe *)
let parse_component context_fields =
  let directory = field_atom "root" "" context_fields in
  let source_dir = field_atom "source_dir" directory context_fields in
  let stanzas = field_list "stanzas" context_fields in

  List.concat_map
    (function
      | Csexp.List
          [ Csexp.List stanza_fields; Csexp.List stanza_data; source_tree ] ->
          if is_library stanza_fields then
            let name, public_name, deps, modules =
              extract_library_info stanza_data source_tree
            in
            [
              {
                Output.component_type = Library;
                name;
                directory;
                source_dir;
                public_name;
                modules;
                dependencies = deps;
              };
            ]
          else if is_executable stanza_fields then
            extract_executable_info stanza_data source_tree
            |> List.map (fun (name, public_name, deps, modules) ->
                   {
                     Output.component_type = Executable;
                     name;
                     directory;
                     source_dir;
                     public_name;
                     modules;
                     dependencies = deps;
                   })
          else []
      | _ -> [])
    stanzas

(* Parse the entire dune describe output *)
let parse_dune_describe_output output =
  try
    let sexps = Csexp.parse_string output in
    match sexps with
    | Ok (Csexp.List fields) ->
        let root = field_atom "root" "" fields in
        let contexts = field_list "contexts" fields in
        let components =
          contexts
          |> List.concat_map (function
               | Csexp.List context_fields -> parse_component context_fields
               | _ -> [])
        in
        Ok (root, components)
    | Ok _ -> Error "Invalid dune describe format"
    | Error (_, msg) -> Error msg
  with exn -> Error (Printexc.to_string exn)

let execute ~sw:_ ~env (_sdk : Ocaml_platform_sdk.t) _args =
  Log.info (fun m -> m "project-structure tool called");
  Log.debug (fun m -> m "Running dune describe workspace");
  
  let debug_enabled = Sys.getenv_opt "OCAML_MCP_DEBUG" <> None in

  (* Run dune describe process *)
  let proc_mgr = Eio.Stdenv.process_mgr env in
  let stdout_buf = Buffer.create 1024 in
  let stderr_buf = Buffer.create 1024 in
  let success, exit_code =
    try
      Eio.Process.run proc_mgr
        [ "dune"; "describe"; "workspace"; "--format=csexp" ]
        ~stdout:(Eio.Flow.buffer_sink stdout_buf)
        ~stderr:(Eio.Flow.buffer_sink stderr_buf);
      (true, Some 0)
    with
    | Eio.Exn.Io (Eio.Process.E (Eio.Process.Child_error (`Exited code)), _) ->
        (false, Some code)
    | _ -> (false, None)
  in
  let stdout_content = Buffer.contents stdout_buf in
  let stderr_content = Buffer.contents stderr_buf in

  let stdout_lines = 
    if stdout_content = "" then 0 else List.length (String.split_on_char '\n' stdout_content)
  in
  let stderr_lines = 
    if stderr_content = "" then 0 else List.length (String.split_on_char '\n' stderr_content)
  in

  let debug_info = 
    if debug_enabled then
      Some {
        Output.command = "dune describe workspace --format=csexp";
        working_directory = ".";
        environment = Printf.sprintf "OCAML_MCP_DEBUG=%s" 
          (Option.value (Sys.getenv_opt "OCAML_MCP_DEBUG") ~default:"(not set)");
        process_success = success;
        exit_code;
        stdout_lines;
        stderr_lines;
      }
    else None
  in

  if success then
    match parse_dune_describe_output stdout_content with
    | Ok (root, components) ->
        Log.debug (fun m -> m "Parsed %d components" (List.length components));
        Ok { Output.project_root = root; build_context = "default"; components; debug_info }
    | Error msg ->
        Log.err (fun m -> m "Failed to parse dune describe output: %s" msg);
        (* Include stderr in error message for debugging *)
        let full_msg = 
          if stderr_content <> "" then
            Printf.sprintf "%s\nstderr: %s" msg stderr_content
          else msg
        in
        Error (Error.Parse_error full_msg)
  else
    let msg =
      match exit_code with
      | Some code ->
          Printf.sprintf "dune describe failed with exit code %d%s" code
            (if stderr_content <> "" then Printf.sprintf "\nstderr: %s" stderr_content else "")
      | None -> 
          Printf.sprintf "dune describe failed%s"
            (if stderr_content <> "" then Printf.sprintf "\nstderr: %s" stderr_content else "")
    in
    Log.err (fun m -> m "%s" msg);
    Error (Error.Dune_describe_failed msg)
