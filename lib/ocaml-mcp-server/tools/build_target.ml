let name = "dune_build_target"
let description = "Build specific files/libraries/tests"

module Args = struct
  type t = { targets : string list } [@@deriving yojson]

  let schema () =
    `Assoc
      [
        ("type", `String "object");
        ( "properties",
          `Assoc
            [
              ( "targets",
                `Assoc
                  [
                    ("type", `String "array");
                    ("items", `Assoc [ ("type", `String "string") ]);
                  ] );
            ] );
        ("required", `List [ `String "targets" ]);
      ]
end

module Output = struct
  type t = { output : string; success : bool } [@@deriving yojson]
end

module Error = struct
  type t = Build_failed of string

  let to_string = function
    | Build_failed msg -> Printf.sprintf "Build failed: %s" msg
end

let execute ~sw:_ ~env (_sdk : Ocaml_platform_sdk.t) (args : Args.t) =
  
  let output_lines = ref [] in
  let add_line line = output_lines := line :: !output_lines in
  let debug_enabled = Sys.getenv_opt "OCAML_MCP_DEBUG" <> None in

  add_line
    (Printf.sprintf "Building targets: %s"
       (String.concat " " args.Args.targets));

  (* Add debug information to output when debug mode is enabled *)
  if debug_enabled then (
    add_line "";
    add_line "=== DEBUG INFO ===";
    add_line (Printf.sprintf "Working directory: %s" ".");
    add_line (Printf.sprintf "Command: dune build %s" (String.concat " " args.Args.targets));
    add_line (Printf.sprintf "Environment: OCAML_MCP_DEBUG=%s" 
      (Option.value (Sys.getenv_opt "OCAML_MCP_DEBUG") ~default:"(not set)"));
    add_line "=================="
  );

  (* Run dune build process *)
  let proc_mgr = Eio.Stdenv.process_mgr env in
  let stdout_buf = Buffer.create 1024 in
  let stderr_buf = Buffer.create 1024 in
  let success, exit_code =
    try
      Eio.Process.run proc_mgr
        ([ "dune"; "build" ] @ args.Args.targets)
        ~stdout:(Eio.Flow.buffer_sink stdout_buf)
        ~stderr:(Eio.Flow.buffer_sink stderr_buf);
      (true, Some 0)
    with
    | Eio.Exn.Io (Eio.Process.Exit_status (`Exited code), _) ->
        (false, Some code)
    | _ -> (false, None)
  in
  let stdout_content = Buffer.contents stdout_buf in
  let stderr_content = Buffer.contents stderr_buf in

  let stdout_lines =
    if stdout_content = "" then [] else String.split_on_char '\n' stdout_content
  in
  let stderr_lines =
    if stderr_content = "" then [] else String.split_on_char '\n' stderr_content
  in

  List.iter (fun line -> if line <> "" then add_line line) stdout_lines;
  List.iter (fun line -> if line <> "" then add_line line) stderr_lines;

  (* Add debug information for process results *)
  if debug_enabled then (
    add_line "";
    add_line "=== PROCESS RESULT ===";
    add_line (Printf.sprintf "Success: %b" success);
    add_line (Printf.sprintf "Exit code: %s" 
      (match exit_code with 
       | Some code -> string_of_int code 
       | None -> "(none)"));
    add_line (Printf.sprintf "Stdout lines: %d" (List.length stdout_lines));
    add_line (Printf.sprintf "Stderr lines: %d" (List.length stderr_lines));
    add_line "====================="
  );

  (* Add exit code information if failed *)
  if not success then
    (match exit_code with
     | Some code -> add_line (Printf.sprintf "[Exit code: %d]" code)
     | None -> add_line "[Process failed with unknown error]");

  if success then (
    (* Only add "Success" if dune didn't already output it *)
    let has_success =
      List.exists
        (fun line ->
          String.trim line = "Success" || String.trim line = "Success.")
        !output_lines
    in
    if not has_success then add_line "Success";
    Ok
      {
        Output.output = String.concat "\n" (List.rev !output_lines);
        success = true;
      })
  else Error (Error.Build_failed (String.concat "\n" (List.rev !output_lines)))
