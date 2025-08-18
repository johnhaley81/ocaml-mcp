type t = Env.t

let create ~sw ~env ~project_root ?(enable_dune = true) () =
  let dune_rpc =
    if enable_dune then (
      let client = Dune_rpc_client.create ~sw ~env ~root:project_root in
      (* Start the polling loop in the background *)
      Eio.Fiber.fork ~sw (fun () ->
          try Dune_rpc_client.run client
          with Eio.Cancel.Cancelled _ -> Dune_rpc_client.close client);
      Some client)
    else None
  in
  let merlin = Merlin_client.create ~project_root in
  let ocamlformat = Ocamlformat_client.create () in
  { Env.dune_rpc; merlin; ocamlformat; project_root; env }

let close t =
  match t.Env.dune_rpc with
  | Some client -> Dune_rpc_client.close client
  | None -> ()

module Dune = Dune

module Merlin = struct
  let find_definition t ~source_path ~source_text ~line ~col =
    Merlin_client.find_definition t.Env.merlin ~source_path ~source_text ~line
      ~col

  let find_references t ~source_path ~source_text ~line ~col =
    Merlin_client.find_references t.Env.merlin ~source_path ~source_text ~line
      ~col

  let type_at_pos t ~source_path ~source_text ~line ~col =
    Merlin_client.type_at_pos t.Env.merlin ~source_path ~source_text ~line ~col

  let document_symbols t ~source_path ~source_text =
    Merlin_client.document_symbols t.Env.merlin ~source_path ~source_text

  let diagnostics t ~source_path ~source_text =
    Merlin_client.diagnostics t.Env.merlin ~source_path ~source_text
end

module Ocamlformat = struct
  let format_doc t ~path ~content =
    Ocamlformat_client.format_doc t.Env.ocamlformat ~path ~content

  let format_type t ~typ = Ocamlformat_client.format_type t.Env.ocamlformat ~typ
end

module Analysis = struct
  let module_signature t ~module_path =
    Ocaml_analysis.get_module_signature ~env:t.Env.env
      ~project_root:t.Env.project_root ~module_path
end
