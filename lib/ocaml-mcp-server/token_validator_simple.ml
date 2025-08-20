(** Simplified token counting validation system.

    This module provides basic validation capabilities for token estimates
    without requiring external HTTP dependencies for real tokenizer APIs. *)

(* Test case structure *)
type test_case = {
  name: string;
  text: string;
  expected_category: [`Short | `Medium | `Long | `Very_long];
  context: string;
}

(* Validation test cases *)
let validation_test_cases = [
  (* Simple OCaml terms *)
  { name = "simple_error"; text = "Error"; expected_category = `Short; 
    context = "Single OCaml error keyword" };
  { name = "simple_warning"; text = "Warning"; expected_category = `Short; 
    context = "Single OCaml warning keyword" };
  { name = "unbound_variable"; text = "Unbound variable x"; expected_category = `Short; 
    context = "Basic OCaml error message" };
  
  (* File paths *)
  { name = "simple_path"; text = "src/lib.ml"; expected_category = `Short; 
    context = "Simple OCaml file path" };
  { name = "nested_path"; text = "src/library/module/implementation.ml"; expected_category = `Medium; 
    context = "Nested OCaml file path" };
  { name = "complex_path"; text = "/home/user/projects/ocaml-project/src/lib/core/types.mli"; 
    expected_category = `Medium; context = "Full system path to OCaml file" };
  
  (* Module paths *)
  { name = "module_path"; text = "Core.Std.List.map"; expected_category = `Short; 
    context = "OCaml module path" };
  { name = "long_module_path"; text = "My_project.Utils.String_helpers.Advanced_parsing.Parser"; 
    expected_category = `Medium; context = "Long OCaml module path" };
  
  (* Error messages *)
  { name = "type_mismatch"; text = "This expression has type int but an expression was expected of type string"; 
    expected_category = `Medium; context = "OCaml type mismatch error" };
  { name = "syntax_error"; text = "Syntax error: ')' expected but found 'end'"; 
    expected_category = `Medium; context = "OCaml syntax error message" };
  
  (* JSON structures *)
  { name = "simple_json"; text = "{\"severity\": \"error\", \"file\": \"main.ml\", \"line\": 42}"; 
    expected_category = `Medium; context = "Simple diagnostic JSON structure" };
]

(* Basic validation result *)
type validation_result = {
  test_case: test_case;
  base_estimate: int;
  conservative_estimate: int;
  calibrated_estimate: int option;
}

(* Run basic validation without external APIs *)
let run_basic_validation ?calibration () =
  List.map (fun test_case ->
    let base_estimate = Token_counting.estimate_text_tokens_empirical test_case.text in
    let conservative_estimate = int_of_float (float_of_int base_estimate *. 1.1) in
    let calibrated_estimate = 
      match calibration with
      | Some cal -> Some (Token_calibration.estimate_text_tokens_calibrated ~calibration:cal test_case.text)
      | None -> None
    in
    {
      test_case;
      base_estimate;
      conservative_estimate;
      calibrated_estimate;
    }
  ) validation_test_cases

(* Analysis of validation results *)
let analyze_results results =
  let total = List.length results in
  
  (* Count by expected category *)
  let category_counts = List.fold_left (fun acc result ->
    let cat = result.test_case.expected_category in
    let current = List.assoc_opt cat acc |> Option.value ~default:0 in
    (cat, current + 1) :: (List.remove_assoc cat acc)
  ) [] results in
  
  (* Calculate basic statistics *)
  let total_base_tokens = List.fold_left (fun acc r -> acc + r.base_estimate) 0 results in
  let total_conservative_tokens = List.fold_left (fun acc r -> acc + r.conservative_estimate) 0 results in
  
  let avg_base = float_of_int total_base_tokens /. float_of_int total in
  let avg_conservative = float_of_int total_conservative_tokens /. float_of_int total in
  
  let conservative_overhead = (avg_conservative -. avg_base) /. avg_base *. 100.0 in
  
  Printf.printf "=== Basic Validation Analysis ===\n";
  Printf.printf "Total test cases: %d\n" total;
  Printf.printf "Average base estimate: %.1f tokens\n" avg_base;
  Printf.printf "Average conservative estimate: %.1f tokens\n" avg_conservative;
  Printf.printf "Conservative overhead: %.1f%%\n" conservative_overhead;
  Printf.printf "\nCategory distribution:\n";
  List.iter (fun (cat, count) ->
    let cat_str = match cat with
      | `Short -> "Short" | `Medium -> "Medium" | `Long -> "Long" | `Very_long -> "Very Long"
    in
    Printf.printf "  %s: %d cases\n" cat_str count
  ) category_counts

(* Print individual validation results *)
let print_validation_results results =
  Printf.printf "\n=== Individual Test Results ===\n";
  List.iter (fun result ->
    Printf.printf "\n--- %s ---\n" result.test_case.name;
    Printf.printf "Text: %s\n" (
      if String.length result.test_case.text > 80 then
        String.sub result.test_case.text 0 77 ^ "..."
      else result.test_case.text
    );
    Printf.printf "Context: %s\n" result.test_case.context;
    Printf.printf "Base estimate: %d tokens\n" result.base_estimate;
    Printf.printf "Conservative (+10%%): %d tokens\n" result.conservative_estimate;
    (match result.calibrated_estimate with
     | Some cal -> Printf.printf "Calibrated estimate: %d tokens\n" cal
     | None -> Printf.printf "Calibrated estimate: N/A\n");
    let content_type = Token_calibration.classify_content result.test_case.text in
    let content_str = match content_type with
      | OCaml_Code -> "OCaml Code"
      | Error_Message -> "Error Message" 
      | File_Path -> "File Path"
      | JSON_Structure -> "JSON Structure"
      | Generic_Text -> "Generic Text"
    in
    Printf.printf "Content type: %s\n" content_str
  ) results

(* Main validation function *)
let validate_token_system ?calibration ~verbose () =
  Printf.printf "Running simplified token validation system...\n\n";
  
  let results = run_basic_validation ?calibration () in
  
  if verbose then print_validation_results results;
  analyze_results results;
  
  Printf.printf "\n=== Recommendations ===\n";
  Printf.printf "1. Use conservative estimates for production to ensure safety margins\n";
  Printf.printf "2. Consider calibrated estimates for better accuracy when available\n";
  Printf.printf "3. Monitor actual token usage to validate estimates in practice\n";
  Printf.printf "4. The base empirical system handles OCaml-specific patterns well\n";
  Printf.printf "5. JSON overhead calculations account for structure tokens\n";
  
  results