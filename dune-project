(lang dune 3.19)

(name ocaml-platform-sdk)

(generate_opam_files true)

(source
 (github tmattio/ocaml-platform-sdk))

(authors "Thibaut Mattio <thibaut.mattio@gmail.com>")

(maintainers "Thibaut Mattio <thibaut.mattio@gmail.com>")

(license ISC)

(implicit_transitive_deps false)

(package
 (name ocaml-platform-sdk)
 (synopsis "Programmatic interface to OCaml Platform tools")
 (description
  "A SDK providing access to OCaml Platform tools including Dune, Merlin, OCamlformat, and more. Designed for building developer tools, LSP servers, MCP servers, and other OCaml development integrations.")
 (depends
  ocaml
  dune-rpc
  (merlin-lib
   (>= 5.5))
  ocamlformat-lib
  eio
  yojson
  ppx_deriving_yojson
  csexp
  logs
  parsexp
  sexplib
  ppx_sexp_conv
  ppx_deriving)
 (tags
  (ocaml-platform sdk tools dune merlin ocamlformat)))
