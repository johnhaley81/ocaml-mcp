type t = {
  dune_rpc : Dune_rpc_client.t option;
  merlin : Merlin_client.t;
  ocamlformat : Ocamlformat_client.t;
  project_root : string;
  env : Eio_unix.Stdenv.base;
}
