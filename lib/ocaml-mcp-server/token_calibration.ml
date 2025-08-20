(** Token estimation calibration system.

    This module provides calibration factors and adjustments for token estimates
    based on empirical data from real tokenizers. It allows fine-tuning our
    estimates to be more accurate while maintaining conservativeness. *)

(* Calibration data structure *)
type calibration_data = {
  (* Category-based multipliers *)
  short_text_factor: float;      (* < 20 tokens *)
  medium_text_factor: float;     (* 20-100 tokens *)
  long_text_factor: float;       (* 100-500 tokens *)
  very_long_factor: float;       (* > 500 tokens *)
  
  (* Content-type specific adjustments *)
  ocaml_code_factor: float;      (* OCaml source code *)
  error_message_factor: float;   (* Error/warning messages *)
  file_path_factor: float;       (* File system paths *)
  json_structure_factor: float;  (* JSON-structured content *)
  
  (* Global adjustments *)
  conservative_margin: float;    (* Additional safety margin (e.g., 1.1 = 10% extra) *)
  minimum_tokens: int;           (* Minimum token count for any text *)
}

(* Default calibration based on initial validation *)
let default_calibration = {
  short_text_factor = 1.0;
  medium_text_factor = 1.05;   (* Slightly higher for medium text *)
  long_text_factor = 1.1;      (* Higher for long text where we tend to under-estimate *)
  very_long_factor = 1.15;     (* Highest adjustment for very long content *)
  
  ocaml_code_factor = 0.95;    (* OCaml code tends to be more compact *)
  error_message_factor = 1.0;  (* Error messages are well-handled *)
  file_path_factor = 0.9;      (* Paths are often over-estimated *)
  json_structure_factor = 1.1; (* JSON overhead is significant *)
  
  conservative_margin = 1.08;   (* 8% safety margin *)
  minimum_tokens = 1;
}

(* Production-ready calibration with conservative estimates *)
let conservative_calibration = {
  short_text_factor = 1.1;
  medium_text_factor = 1.15;
  long_text_factor = 1.2;
  very_long_factor = 1.25;
  
  ocaml_code_factor = 1.0;     (* Don't reduce for production *)
  error_message_factor = 1.05;
  file_path_factor = 1.0;      (* Conservative for paths too *)
  json_structure_factor = 1.15;
  
  conservative_margin = 1.15;  (* 15% safety margin *)
  minimum_tokens = 1;
}

(* Content classification for calibration *)
type content_type = 
  | OCaml_Code
  | Error_Message
  | File_Path
  | JSON_Structure
  | Generic_Text

let classify_content (text: string) : content_type =
  let text_lower = String.lowercase_ascii text in
  
  (* Check for OCaml code patterns *)
  if Str.string_match (Str.regexp ".*\\.mli?\\b") text 0 ||
     String.contains text '(' && String.contains text ')' &&
     (Str.string_match (Str.regexp ".*\\blet\\b\\|\\btype\\b\\|\\bmodule\\b") text_lower 0)
  then OCaml_Code
  
  (* Check for error/warning messages *)
  else if Str.string_match (Str.regexp ".*\\b\\(error\\|warning\\|exception\\)\\b") text_lower 0 ||
          String.contains text ':' && 
          (Str.string_match (Str.regexp ".*line.*\\|.*column.*\\|.*character.*") text_lower 0)
  then Error_Message
  
  (* Check for file paths *)
  else if String.contains text '/' || String.contains text '\\' ||
          Str.string_match (Str.regexp ".*\\.[a-zA-Z]{1,4}$") text 0
  then File_Path
  
  (* Check for JSON structure *)
  else if (String.contains text '{' && String.contains text '}') ||
          (String.contains text '[' && String.contains text ']') ||
          String.contains text ':' && String.contains text '"'
  then JSON_Structure
  
  (* Default to generic text *)
  else Generic_Text

(* Length-based classification *)
let classify_length (estimated_tokens: int) : [`Short | `Medium | `Long | `Very_long] =
  if estimated_tokens < 20 then `Short
  else if estimated_tokens < 100 then `Medium
  else if estimated_tokens < 500 then `Long
  else `Very_long

(* Apply calibration to a token estimate *)
let apply_calibration ?(calibration = default_calibration) ~text ~base_estimate () =
  let content_type = classify_content text in
  let length_category = classify_length base_estimate in
  
  (* Get length-based factor *)
  let length_factor = match length_category with
    | `Short -> calibration.short_text_factor
    | `Medium -> calibration.medium_text_factor
    | `Long -> calibration.long_text_factor
    | `Very_long -> calibration.very_long_factor
  in
  
  (* Get content-type factor *)
  let content_factor = match content_type with
    | OCaml_Code -> calibration.ocaml_code_factor
    | Error_Message -> calibration.error_message_factor
    | File_Path -> calibration.file_path_factor
    | JSON_Structure -> calibration.json_structure_factor
    | Generic_Text -> 1.0
  in
  
  (* Apply all factors *)
  let adjusted_estimate = 
    float_of_int base_estimate *.
    length_factor *.
    content_factor *.
    calibration.conservative_margin
  in
  
  (* Ensure minimum and round up *)
  max calibration.minimum_tokens (int_of_float (ceil adjusted_estimate))

(* Calibrated version of the main estimation function *)
let estimate_text_tokens_calibrated ?(calibration = default_calibration) (text : string) : int =
  let base_estimate = Token_counting.estimate_text_tokens_empirical text in
  apply_calibration ~calibration ~text ~base_estimate ()

(* Calibrated diagnostic estimation *)
let estimate_diagnostic_tokens_calibrated ?(calibration = default_calibration) (d : Build_types.Output.diagnostic) : int =
  let base_estimate = Token_counting.estimate_diagnostic_tokens d in
  
  (* Create representative text for classification *)
  let repr_text = Printf.sprintf "%s %s %s" d.severity d.file d.message in
  
  apply_calibration ~calibration ~text:repr_text ~base_estimate ()

(* Calibrated response estimation *)
let estimate_response_tokens_calibrated ?(calibration = default_calibration) (output : Build_types.Output.t) : int =
  let base_estimate = Token_counting.estimate_response_tokens output in
  
  (* Create representative text from the response *)
  let diagnostic_messages = List.map (fun d -> d.Build_types.Output.message) output.diagnostics in
  let repr_text = String.concat " " (output.status :: diagnostic_messages) in
  
  apply_calibration ~calibration ~text:repr_text ~base_estimate ()

(* Validation-based calibration adjustment *)
module Validation_Based_Calibration = struct
  type validation_point = {
    text: string;
    our_estimate: int;
    actual_tokens: int;
    content_type: content_type;
    length_category: [`Short | `Medium | `Long | `Very_long];
  }
  
  type calibration_metrics = {
    accuracy: float;        (* How close our estimates are on average *)
    conservativeness: float; (* What fraction of estimates are conservative *)
    category_errors: (content_type * float) list; (* Error by content type *)
    length_errors: ([`Short | `Medium | `Long | `Very_long] * float) list; (* Error by length *)
  }
  
  let calculate_metrics (validation_points: validation_point list) : calibration_metrics =
    if validation_points = [] then
      { accuracy = 0.0; conservativeness = 0.0; category_errors = []; length_errors = [] }
    else
      let n = List.length validation_points in
      
      (* Calculate overall accuracy *)
      let total_error = List.fold_left (fun acc vp ->
        let error = abs (vp.our_estimate - vp.actual_tokens) |> float_of_int in
        let relative_error = error /. (max 1 vp.actual_tokens |> float_of_int) in
        acc +. relative_error
      ) 0.0 validation_points in
      let accuracy = 1.0 -. (total_error /. float_of_int n) in
      
      (* Calculate conservativeness *)
      let conservative_count = List.fold_left (fun acc vp ->
        if vp.our_estimate >= vp.actual_tokens then acc + 1 else acc
      ) 0 validation_points in
      let conservativeness = float_of_int conservative_count /. float_of_int n in
      
      (* Calculate category-specific errors *)
      let category_groups = List.fold_left (fun acc vp ->
        let current = List.assoc_opt vp.content_type acc |> Option.value ~default:[] in
        let updated = (vp :: current) in
        (vp.content_type, updated) :: (List.remove_assoc vp.content_type acc)
      ) [] validation_points in
      
      let category_errors = List.map (fun (cat, points) ->
        let avg_error = List.fold_left (fun acc vp ->
          let error = abs (vp.our_estimate - vp.actual_tokens) |> float_of_int in
          let relative_error = error /. (max 1 vp.actual_tokens |> float_of_int) in
          acc +. relative_error
        ) 0.0 points in
        (cat, avg_error /. (List.length points |> float_of_int))
      ) category_groups in
      
      (* Similar for length categories - simplified for brevity *)
      let length_errors = [] in (* TODO: implement similar grouping for length *)
      
      { accuracy; conservativeness; category_errors; length_errors }
  
  let suggest_calibration_adjustments (metrics: calibration_metrics) (base_calibration: calibration_data) : calibration_data =
    (* Adjust based on accuracy and conservativeness *)
    let global_adjustment = 
      if metrics.accuracy < 0.8 then 1.1  (* Increase estimates if too inaccurate *)
      else if metrics.conservativeness < 0.6 then 1.1  (* Increase if not conservative enough *)
      else if metrics.conservativeness > 0.9 then 0.95 (* Decrease if too conservative *)
      else 1.0
    in
    
    (* Adjust content-type factors based on category errors *)
    let adjusted_ocaml = List.assoc_opt OCaml_Code metrics.category_errors 
      |> Option.map (fun err -> if err > 0.3 then base_calibration.ocaml_code_factor *. 1.1 else base_calibration.ocaml_code_factor)
      |> Option.value ~default:base_calibration.ocaml_code_factor in
    
    let adjusted_error = List.assoc_opt Error_Message metrics.category_errors
      |> Option.map (fun err -> if err > 0.3 then base_calibration.error_message_factor *. 1.1 else base_calibration.error_message_factor)
      |> Option.value ~default:base_calibration.error_message_factor in
    
    let adjusted_path = List.assoc_opt File_Path metrics.category_errors
      |> Option.map (fun err -> if err > 0.3 then base_calibration.file_path_factor *. 1.1 else base_calibration.file_path_factor)
      |> Option.value ~default:base_calibration.file_path_factor in
    
    let adjusted_json = List.assoc_opt JSON_Structure metrics.category_errors
      |> Option.map (fun err -> if err > 0.3 then base_calibration.json_structure_factor *. 1.1 else base_calibration.json_structure_factor)
      |> Option.value ~default:base_calibration.json_structure_factor in
    
    {
      base_calibration with
      conservative_margin = base_calibration.conservative_margin *. global_adjustment;
      ocaml_code_factor = adjusted_ocaml;
      error_message_factor = adjusted_error;
      file_path_factor = adjusted_path;
      json_structure_factor = adjusted_json;
    }
end

(* Load calibration from file or use default *)
let load_calibration ?(file_path = "token_calibration.json") () =
  try
    let content = In_channel.with_open_text file_path In_channel.input_all in
    let json = Yojson.Safe.from_string content in
    let open Yojson.Safe.Util in
    {
      short_text_factor = json |> member "short_text_factor" |> to_float;
      medium_text_factor = json |> member "medium_text_factor" |> to_float;
      long_text_factor = json |> member "long_text_factor" |> to_float;
      very_long_factor = json |> member "very_long_factor" |> to_float;
      ocaml_code_factor = json |> member "ocaml_code_factor" |> to_float;
      error_message_factor = json |> member "error_message_factor" |> to_float;
      file_path_factor = json |> member "file_path_factor" |> to_float;
      json_structure_factor = json |> member "json_structure_factor" |> to_float;
      conservative_margin = json |> member "conservative_margin" |> to_float;
      minimum_tokens = json |> member "minimum_tokens" |> to_int;
    }
  with
  | Sys_error _ | Yojson.Json_error _ -> default_calibration

(* Save calibration to file *)
let save_calibration ?(file_path = "token_calibration.json") (calibration: calibration_data) =
  let json = `Assoc [
    ("short_text_factor", `Float calibration.short_text_factor);
    ("medium_text_factor", `Float calibration.medium_text_factor);
    ("long_text_factor", `Float calibration.long_text_factor);
    ("very_long_factor", `Float calibration.very_long_factor);
    ("ocaml_code_factor", `Float calibration.ocaml_code_factor);
    ("error_message_factor", `Float calibration.error_message_factor);
    ("file_path_factor", `Float calibration.file_path_factor);
    ("json_structure_factor", `Float calibration.json_structure_factor);
    ("conservative_margin", `Float calibration.conservative_margin);
    ("minimum_tokens", `Int calibration.minimum_tokens);
  ] in
  let content = Yojson.Safe.pretty_to_string json in
  Out_channel.with_open_text file_path (fun oc -> 
    Out_channel.output_string oc content)

(* Print calibration info *)
let print_calibration (calibration: calibration_data) =
  Printf.printf "=== Token Calibration Settings ===\n";
  Printf.printf "Length factors:\n";
  Printf.printf "  Short text: %.3f\n" calibration.short_text_factor;
  Printf.printf "  Medium text: %.3f\n" calibration.medium_text_factor;
  Printf.printf "  Long text: %.3f\n" calibration.long_text_factor;
  Printf.printf "  Very long text: %.3f\n" calibration.very_long_factor;
  Printf.printf "\nContent type factors:\n";
  Printf.printf "  OCaml code: %.3f\n" calibration.ocaml_code_factor;
  Printf.printf "  Error messages: %.3f\n" calibration.error_message_factor;
  Printf.printf "  File paths: %.3f\n" calibration.file_path_factor;
  Printf.printf "  JSON structure: %.3f\n" calibration.json_structure_factor;
  Printf.printf "\nGlobal settings:\n";
  Printf.printf "  Conservative margin: %.3f (%.1f%% extra)\n" 
    calibration.conservative_margin ((calibration.conservative_margin -. 1.0) *. 100.0);
  Printf.printf "  Minimum tokens: %d\n" calibration.minimum_tokens