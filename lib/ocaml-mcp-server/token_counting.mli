(** Token counting system for build status responses.

    This module provides empirically-validated token counting for various
    text patterns commonly found in OCaml/Dune build outputs. *)

(** Cache module for performance optimization *)
module TokenCache : sig
  val get_or_compute : string -> (unit -> int) -> int
  (** [get_or_compute key compute_fn] returns cached value for key or computes and caches it *)
end

val estimate_text_tokens_empirical : string -> int
(** [estimate_text_tokens_empirical text] estimates token count for text using OCaml-specific patterns *)

val estimate_json_field_overhead : string -> [`String | `Number | `Boolean | `Array | `Object] -> int
(** [estimate_json_field_overhead field_name field_type] calculates JSON structure overhead *)

val estimate_diagnostic_tokens : Build_types.Output.diagnostic -> int
(** [estimate_diagnostic_tokens diagnostic] estimates token count for a diagnostic entry *)

val estimate_response_tokens : Build_types.Output.t -> int
(** [estimate_response_tokens output] estimates total token count for build status response *)