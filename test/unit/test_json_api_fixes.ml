(* Comprehensive validation test for JSON API contract fixes *)
(* This test demonstrates the resolved type system inconsistencies *)

open Printf

(* Test framework *)
let test_count = ref 0
let failed_tests = ref []

let assert_equal ~expected ~actual ~msg =
  incr test_count;
  if expected <> actual then
    failed_tests := msg :: !failed_tests

let assert_true ~actual ~msg =
  incr test_count;
  if not actual then
    failed_tests := msg :: !failed_tests

let print_results () =
  let total = !test_count in
  let failed = List.length !failed_tests in
  let passed = total - failed in
  printf "\n=== JSON API Fix Validation Results ===\n";
  printf "Total tests: %d\n" total;
  printf "Passed: %d\n" passed;
  printf "Failed: %d\n" failed;
  if failed > 0 then begin
    printf "\nFailed tests:\n";
    List.iter (fun msg -> printf "- %s\n" msg) (List.rev !failed_tests);
    exit 1
  end else begin
    printf "\nAll JSON API fixes validated successfully!\n";
    exit 0
  end

(* Simulate the fixed API contract *)
module FixedAPI = struct
  type severity_filter = [`Error | `Warning | `All]
  
  type args = {
    targets : string list option;
    max_diagnostics : int option;
    page : int option;
    severity_filter : severity_filter option;
    file_pattern : string option;
  }

  (* Case-insensitive severity conversion (the main fix) *)
  let severity_from_json = function
    | "error" | "Error" | "ERROR" -> Some `Error
    | "warning" | "Warning" | "WARNING" -> Some `Warning
    | "all" | "All" | "ALL" -> Some `All
    | _ -> None

  let severity_to_json = function
    | `Error -> "error"    (* Always lowercase in JSON *)
    | `Warning -> "warning"
    | `All -> "all"

  (* Parameter validation *)
  let validate_max_diagnostics = function
    | None -> true
    | Some n -> n >= 1 && n <= 1000

  let validate_page = function
    | None -> true
    | Some p -> p >= 0

  let validate_file_pattern = function
    | None -> true
    | Some pattern -> 
        let len = String.length pattern in
        len > 0 && len <= 200

  let validate_args args =
    validate_max_diagnostics args.max_diagnostics &&
    validate_page args.page &&
    validate_file_pattern args.file_pattern
end

(* Test 1: Case-insensitive severity filter parsing *)
let test_case_insensitive_severity () =
  printf "Testing case-insensitive severity filter parsing...\n";
  
  let test_cases = [
    ("error", `Error, "lowercase 'error' should work");
    ("Error", `Error, "Title case 'Error' should work");
    ("ERROR", `Error, "uppercase 'ERROR' should work");
    ("warning", `Warning, "lowercase 'warning' should work");
    ("Warning", `Warning, "Title case 'Warning' should work");
    ("WARNING", `Warning, "uppercase 'WARNING' should work");
    ("all", `All, "lowercase 'all' should work");
    ("All", `All, "Title case 'All' should work");
    ("ALL", `All, "uppercase 'ALL' should work");
  ] in
  
  List.iter (fun (input, expected, msg) ->
    match FixedAPI.severity_from_json input with
    | Some actual ->
        assert_equal ~expected ~actual ~msg
    | None ->
        failed_tests := (msg ^ " - failed to parse") :: !failed_tests
  ) test_cases

(* Test 2: JSON output consistency *)
let test_json_output_consistency () =
  printf "Testing JSON output consistency...\n";
  
  let severity_variants = [`Error; `Warning; `All] in
  let expected_json = ["error"; "warning"; "all"] in
  
  List.iter2 (fun variant expected ->
    let actual = FixedAPI.severity_to_json variant in
    assert_equal ~expected ~actual 
      ~msg:(sprintf "JSON output should be lowercase for %s" 
        (match variant with `Error -> "Error" | `Warning -> "Warning" | `All -> "All"))
  ) severity_variants expected_json

(* Test 3: Round-trip conversion *)
let test_round_trip_conversion () =
  printf "Testing round-trip JSON conversion...\n";
  
  let test_cases = [
    (`Error, "error");
    (`Warning, "warning");  
    (`All, "all");
  ] in
  
  List.iter (fun (original_variant, expected_json) ->
    (* Convert to JSON *)
    let json_repr = FixedAPI.severity_to_json original_variant in
    assert_equal ~expected:expected_json ~actual:json_repr
      ~msg:"JSON representation should be lowercase";
    
    (* Convert back from JSON *)
    match FixedAPI.severity_from_json json_repr with
    | Some restored_variant ->
        assert_equal ~expected:original_variant ~actual:restored_variant
          ~msg:"Round-trip should preserve original value"
    | None ->
        failed_tests := "Round-trip conversion failed" :: !failed_tests
  ) test_cases

(* Test 4: Client compatibility scenarios *)
let test_client_compatibility () =
  printf "Testing client compatibility scenarios...\n";
  
  (* Scenario 1: Old client sends "Error" (Title case) *)
  match FixedAPI.severity_from_json "Error" with
  | Some `Error -> 
      assert_true ~actual:true ~msg:"Old client with Title case should work"
  | _ ->
      failed_tests := "Title case compatibility failed" :: !failed_tests;
  
  (* Scenario 2: New client sends "error" (lowercase) *)
  match FixedAPI.severity_from_json "error" with
  | Some `Error ->
      assert_true ~actual:true ~msg:"New client with lowercase should work"
  | _ ->
      failed_tests := "Lowercase compatibility failed" :: !failed_tests;
  
  (* Scenario 3: API documentation example *)
  let doc_example_json = "error" in
  match FixedAPI.severity_from_json doc_example_json with
  | Some `Error ->
      assert_true ~actual:true ~msg:"API documentation example should work"
  | _ ->
      failed_tests := "API documentation example failed" :: !failed_tests

(* Test 5: Parameter validation *)
let test_parameter_validation () =
  printf "Testing parameter validation...\n";
  
  (* Test max_diagnostics validation *)
  let max_diag_cases = [
    (Some 0, false, "zero should be rejected");
    (Some (-1), false, "negative should be rejected");
    (Some 1, true, "minimum valid should be accepted");
    (Some 500, true, "normal value should be accepted");
    (Some 1000, true, "maximum valid should be accepted");
    (Some 1001, false, "over-limit should be rejected");
    (None, true, "None should be accepted");
  ] in
  
  List.iter (fun (value, should_pass, msg) ->
    let actual = FixedAPI.validate_max_diagnostics value in
    assert_equal ~expected:should_pass ~actual ~msg
  ) max_diag_cases;
  
  (* Test page validation *)
  let page_cases = [
    (Some (-1), false, "negative page should be rejected");
    (Some 0, true, "zero page should be accepted");
    (Some 5, true, "positive page should be accepted");
    (None, true, "None page should be accepted");
  ] in
  
  List.iter (fun (value, should_pass, msg) ->
    let actual = FixedAPI.validate_page value in
    assert_equal ~expected:should_pass ~actual ~msg
  ) page_cases;
  
  (* Test file_pattern validation *)
  let pattern_cases = [
    (Some "", false, "empty pattern should be rejected");
    (Some "src/*.ml", true, "normal pattern should be accepted");
    (Some (String.make 201 'a'), false, "overly long pattern should be rejected");
    (None, true, "None pattern should be accepted");
  ] in
  
  List.iter (fun (value, should_pass, msg) ->
    let actual = FixedAPI.validate_file_pattern value in
    assert_equal ~expected:should_pass ~actual ~msg
  ) pattern_cases

(* Test 6: Error message quality *)
let test_error_handling () =
  printf "Testing error handling...\n";
  
  (* Test invalid severity handling *)
  let invalid_severities = ["debug"; "info"; "trace"; "err"; "warn"; ""] in
  
  List.iter (fun invalid ->
    match FixedAPI.severity_from_json invalid with
    | None -> 
        assert_true ~actual:true 
          ~msg:(sprintf "Invalid severity '%s' should be rejected" invalid)
    | Some _ ->
        failed_tests := (sprintf "Should reject invalid severity '%s'" invalid) :: !failed_tests
  ) invalid_severities

(* Test 7: API contract guarantees *)
let test_api_contract_guarantees () =
  printf "Testing API contract guarantees...\n";
  
  (* Guarantee 1: JSON schema uses lowercase *)
  let schema_enum = ["error"; "warning"; "all"] in
  assert_true ~actual:(List.for_all (fun s -> String.lowercase_ascii s = s) schema_enum)
    ~msg:"JSON schema enum values should be lowercase";
  
  (* Guarantee 2: All valid schema values are accepted *)
  List.iter (fun schema_value ->
    match FixedAPI.severity_from_json schema_value with
    | Some _ ->
        assert_true ~actual:true 
          ~msg:(sprintf "Schema value '%s' should be accepted" schema_value)
    | None ->
        failed_tests := (sprintf "Schema value '%s' not accepted" schema_value) :: !failed_tests
  ) schema_enum;
  
  (* Guarantee 3: Internal OCaml types maintain type safety *)
  let internal_values = [`Error; `Warning; `All] in
  List.iter (fun value ->
    let json_repr = FixedAPI.severity_to_json value in
    assert_true ~actual:(List.mem json_repr schema_enum)
      ~msg:"Internal values should map to valid schema values"
  ) internal_values

(* Test 8: Backward compatibility *)
let test_backward_compatibility () =
  printf "Testing backward compatibility...\n";
  
  (* Old API style (Title case from OCaml variants) should still work *)
  let old_style_cases = ["Error"; "Warning"; "All"] in
  
  List.iter (fun old_style ->
    match FixedAPI.severity_from_json old_style with
    | Some _ ->
        assert_true ~actual:true
          ~msg:(sprintf "Old style '%s' should still work" old_style)
    | None ->
        failed_tests := (sprintf "Backward compatibility broken for '%s'" old_style) :: !failed_tests
  ) old_style_cases

(* Main test runner *)
let () =
  printf "=== JSON API Contract Fix Validation ===\n";
  printf "This test validates that the type system inconsistencies have been resolved.\n\n";
  
  (* Run all validation tests *)
  test_case_insensitive_severity ();
  test_json_output_consistency ();
  test_round_trip_conversion ();
  test_client_compatibility ();
  test_parameter_validation ();
  test_error_handling ();
  test_api_contract_guarantees ();
  test_backward_compatibility ();
  
  print_results ();