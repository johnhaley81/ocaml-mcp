(** Testing support module implementation *)

module Build_status = struct
  (* Re-export the internal types from the actual build_status tool *)
  module Args = Build_status.Args
  module Output = Build_status.Output
end