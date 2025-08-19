(** High-Performance Streaming Diagnostic Processor for build status results.

    This module provides efficient stream processing for diagnostic data,
    including priority-based sorting, filtering, and pagination. *)

type 'a stream = unit -> 'a option
(** Lazy stream type *)

(** Priority queue implementation for error-first sorting *)
module PriorityBuffer : sig
  type t
  (** Priority buffer that separates errors from warnings *)
  
  val create : int -> t
  (** [create max_size] creates buffer with maximum capacity *)
  
  val add_diagnostic : t -> Build_types.Output.diagnostic -> t
  (** [add_diagnostic buffer diag] adds diagnostic to appropriate priority queue *)
  
  val to_stream : t -> Build_types.Output.diagnostic stream
  (** [to_stream buffer] converts buffer to stream with errors first *)
  
  val current_size : t -> int
  (** [current_size buffer] gets the current size of the buffer *)
  
  val max_size : t -> int
  (** [max_size buffer] gets the maximum size of the buffer *)
end

val severity_predicate : [`All | `Error | `Warning] -> (Build_types.Output.diagnostic -> bool)
(** [severity_predicate filter] creates predicate function for severity filtering *)

val file_pattern_predicate : string option -> (Build_types.Output.diagnostic -> bool)
(** [file_pattern_predicate pattern] creates predicate function for file pattern matching *)

val filter_stream : predicate:(Build_types.Output.diagnostic -> bool) -> Build_types.Output.diagnostic stream -> Build_types.Output.diagnostic stream
(** [filter_stream ~predicate stream] filters stream using predicate function *)

val take_while_under_token_limit : token_limit:int -> metadata_tokens:int -> Build_types.Output.diagnostic stream -> Build_types.Output.diagnostic stream
(** [take_while_under_token_limit ~token_limit ~metadata_tokens stream] limits stream by token count *)

val take_page : page:int -> page_size:int -> Build_types.Output.diagnostic stream -> Build_types.Output.diagnostic stream
(** [take_page ~page ~page_size stream] implements pagination on stream *)

val of_list : Build_types.Output.diagnostic list -> Build_types.Output.diagnostic stream
(** [of_list lst] converts list to stream *)

val to_list : ?limit:int -> Build_types.Output.diagnostic stream -> Build_types.Output.diagnostic list
(** [to_list ?limit stream] materializes stream to list with optional limit *)