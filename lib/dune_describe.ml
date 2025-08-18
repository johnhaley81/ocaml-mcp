(*
  dune_describe.ml

  Copyright (c) 2023 Simmo Saan

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*)

open Sexplib.Std

module Digest = struct
  include String

  let hash = Hashtbl.hash
  let t_of_sexp = string_of_sexp
end

type module_deps = { for_intf : string list; for_impl : string list }
[@@deriving of_sexp] [@@sexp.allow_extra_fields]

type module_ = {
  name : string;
  impl : string option;
  intf : string option; [@sexp.option]
  module_deps : module_deps option; [@sexp.option]
}
[@@deriving of_sexp] [@@sexp.allow_extra_fields]

type executable = {
  names : string list;
  requires : Digest.t list;
  modules : module_ list;
}
[@@deriving of_sexp] [@@sexp.allow_extra_fields]

type library = {
  name : string;
  uid : Digest.t;
  requires : Digest.t list;
  local : bool;
  modules : module_ list;
}
[@@deriving of_sexp] [@@sexp.allow_extra_fields]

type entry =
  | Library of library
  | Executables of executable
  | Root of string
  | Build_context of string
[@@deriving of_sexp]

type t = entry list [@@deriving of_sexp]
