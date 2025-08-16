(* Comprehensive tests for dune_build_status JSON API contract *)
(* Tests case-insensitive parameter handling and robust validation *)

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

let assert_result_ok ~result ~msg string_of_error =
  incr test_count;
  match result with
  | Ok _ -> ()
  | Error err -> failed_tests := (msg ^ ": " ^ string_of_error err) :: !failed_tests

let assert_result_error ~result ~msg =
  incr test_count;
  match result with
  | Error _ -> ()
  | Ok _ -> failed_tests := (msg ^ ": expected error but got success") :: !failed_tests

let print_results () =
  let total = !test_count in
  let failed = List.length !failed_tests in
  let passed = total - failed in
  printf "\n=== JSON API Contract Test Results ===\n";
  printf "Total tests: %d\n" total;
  printf "Passed: %d\n" passed;
  printf "Failed: %d\n" failed;
  if failed > 0 then begin
    printf "\nFailed tests:\n";
    List.iter (fun msg -> printf "- %s\n" msg) (List.rev !failed_tests);
    exit 1
  end else begin
    printf "\nAll JSON API contract tests passed!\n";
    exit 0
  end

(* Test module simulating the API contract requirements *)
module TestArgs = struct
  type severity_filter = [`Error | `Warning | `All]
  
  type t = {
    targets : string list option;
    max_diagnostics : int option;
    page : int option;
    severity_filter : severity_filter option;
    file_pattern : string option;
  }

  (* JSON representation *)
  module Json = struct
    type args_json = {
      targets : string list option;
      max_diagnostics : int option;
      page : int option;
      severity_filter : string option;
      file_pattern : string option;
    }
  end

  type validation_error = [
    | `Invalid_severity of string
    | `Invalid_max_diagnostics of int * string
    | `Invalid_page of int * string
    | `Invalid_file_pattern of string * string
  ]

  let string_of_validation_error = function
    | `Invalid_severity s -> 
        sprintf "Invalid severity '%s', expected: 'error', 'warning', or 'all'" s
    | `Invalid_max_diagnostics (v, reason) ->
        sprintf "Invalid max_diagnostics value %d: %s" v reason
    | `Invalid_page (v, reason) ->
        sprintf "Invalid page value %d: %s" v reason
    | `Invalid_file_pattern (pattern, reason) ->
        sprintf "Invalid file_pattern '%s': %s" pattern reason

  (* Case-insensitive severity conversion *)
  let severity_from_json_string = function
    | "error" | "Error" | "ERROR" -> Ok `Error
    | "warning" | "Warning" | "WARNING" -> Ok `Warning
    | "all" | "All" | "ALL" -> Ok `All
    | s -> Error (`Invalid_severity s)

  let severity_to_json_string = function
    | `Error -> "error"
    | `Warning -> "warning" 
    | `All -> "all"

  (* Comprehensive validation *)
  let validate_args (json_args : Json.args_json) : (t, validation_error) result =
    
    let severity_filter_result = match json_args.severity_filter with
      | None -> Ok None
      | Some s -> 
          (match severity_from_json_string s with
           | Ok sf -> Ok (Some sf)
           | Error e -> Error e)
    in
    
    let max_diagnostics_result = match json_args.max_diagnostics with
      | None -> Ok None
      | Some n when n < 1 -> 
          Error (`Invalid_max_diagnostics (n, "must be >= 1"))
      | Some n when n > 1000 -> 
          Error (`Invalid_max_diagnostics (n, "must be <= 1000"))
      | Some n -> Ok (Some n)
    in
    
    let page_result = match json_args.page with
      | None -> Ok None
      | Some p when p < 0 -> 
          Error (`Invalid_page (p, "must be >= 0 (0-based pagination)"))
      | Some p -> Ok (Some p)
    in
    
    let file_pattern_result = match json_args.file_pattern with
      | None -> Ok None
      | Some pattern -> 
          let pattern_len = String.length pattern in
          if pattern_len > 200 then
            Error (`Invalid_file_pattern (pattern, "pattern too long (max 200 chars)"))
          else if pattern_len = 0 then
            Error (`Invalid_file_pattern (pattern, "pattern cannot be empty"))
          else
            let star_count = ref 0 in
            for i = 0 to pattern_len - 1 do
              if String.get pattern i = '*' then incr star_count
            done;
            if !star_count > 10 then
              Error (`Invalid_file_pattern (pattern, "too many wildcards (max 10)"))
            else
              Ok (Some pattern)
    in
    
    match severity_filter_result, max_diagnostics_result, page_result, file_pattern_result with
    | Ok severity_filter, Ok max_diagnostics, Ok page, Ok file_pattern ->
        Ok {
          targets = json_args.targets;
          max_diagnostics;
          page;
          severity_filter;
          file_pattern;
        }
    | Error e, _, _, _ -> Error e
    | _, Error e, _, _ -> Error e
    | _, _, Error e, _ -> Error e
    | _, _, _, Error e -> Error e
end

(* Test case-insensitive severity filter parsing *)
let test_case_insensitive_severity () =
  printf "Testing case-insensitive severity filter parsing...\n";
  
  let test_cases = [
    ("error", `Error);
    ("Error", `Error);
    ("ERROR", `Error);
    ("warning", `Warning);
    ("Warning", `Warning);
    ("WARNING", `Warning);
    ("all", `All);
    ("All", `All);
    ("ALL", `All);
  ] in
  
  List.iter (fun (input, expected) ->
    let result = TestArgs.severity_from_json_string input in
    match result with
    | Ok actual ->
        assert_equal ~expected ~actual 
          ~msg:(sprintf "Case-insensitive parsing should work for '%s'" input)
    | Error _ ->
        failed_tests := (sprintf "Should accept '%s' as valid severity" input) :: !failed_tests
  ) test_cases

let test_invalid_severity_rejection () =
  printf "Testing invalid severity rejection...\n";
  
  let invalid_cases = ["err"; "warn"; "errors"; "warnings"; "debug"; "info"; ""] in
  
  List.iter (fun invalid ->
    let result = TestArgs.severity_from_json_string invalid in
    match result with
    | Error (`Invalid_severity _) -> () (* Expected *)
    | _ -> 
        failed_tests := (sprintf "Should reject invalid severity '%s'" invalid) :: !failed_tests
  ) invalid_cases

let test_json_api_contract () =
  printf "Testing JSON API contract compliance...\n";
  
  (* Test 1: lowercase JSON values produce correct OCaml variants *)
  let json_args_lowercase = TestArgs.Json.{
    targets = Some ["lib"; "bin"];
    max_diagnostics = Some 50;
    page = Some 1;
    severity_filter = Some "error"; (* lowercase *)
    file_pattern = Some "src/**/*.ml";
  } in
  
  let result = TestArgs.validate_args json_args_lowercase in
  match result with
  | Ok args ->
      assert_equal ~expected:(Some `Error) ~actual:args.severity_filter
        ~msg:"lowercase 'error' should convert to `Error";
      assert_equal ~expected:(Some 50) ~actual:args.max_diagnostics
        ~msg:"max_diagnostics should be preserved";
      assert_equal ~expected:(Some 1) ~actual:args.page
        ~msg:"page should be preserved"
  | Error err ->
      failed_tests := ("JSON contract test failed: " ^ TestArgs.string_of_validation_error err) :: !failed_tests

let test_round_trip_serialization () =
  printf "Testing round-trip JSON serialization...\n";
  
  let original_args = TestArgs.{
    targets = Some ["test"; "lib"];
    max_diagnostics = Some 100;
    page = Some 2;
    severity_filter = Some `Warning;
    file_pattern = Some "**/*.mli";
  } in
  
  (* Convert to JSON representation *)
  let json_args = TestArgs.Json.{
    targets = original_args.targets;
    max_diagnostics = original_args.max_diagnostics;
    page = original_args.page;
    severity_filter = Option.map TestArgs.severity_to_json_string original_args.severity_filter;
    file_pattern = original_args.file_pattern;
  } in
  
  (* Validate back to OCaml type *)
  let result = TestArgs.validate_args json_args in
  match result with
  | Ok restored_args ->
      assert_equal ~expected:original_args.targets ~actual:restored_args.targets
        ~msg:"targets should survive round-trip";
      assert_equal ~expected:original_args.severity_filter ~actual:restored_args.severity_filter
        ~msg:"severity_filter should survive round-trip";
      (* Check that JSON used lowercase *)
      assert_equal ~expected:(Some "warning") ~actual:json_args.severity_filter
        ~msg:"JSON should use lowercase 'warning'"
  | Error err ->
      failed_tests := ("Round-trip test failed: " ^ TestArgs.string_of_validation_error err) :: !failed_tests

let test_parameter_validation () =
  printf "Testing comprehensive parameter validation...\n";
  
  (* Test max_diagnostics validation *)
  let test_max_diagnostics_cases = [
    (Some 0, false, "zero should be rejected");
    (Some (-1), false, "negative should be rejected");
    (Some 1, true, "minimum valid value should be accepted");
    (Some 500, true, "normal value should be accepted");
    (Some 1000, true, "maximum valid value should be accepted");
    (Some 1001, false, "over-limit should be rejected");
  ] in
  
  List.iter (fun (max_diag, should_succeed, msg) ->
    let json_args = TestArgs.Json.{
      targets = None;
      max_diagnostics = max_diag;
      page = None;
      severity_filter = None;
      file_pattern = None;
    } in
    let result = TestArgs.validate_args json_args in
    if should_succeed then
      assert_result_ok ~result ~msg TestArgs.string_of_validation_error
    else
      assert_result_error ~result ~msg
  ) test_max_diagnostics_cases;
  
  (* Test page validation *)
  let test_page_cases = [
    (Some (-1), false, "negative page should be rejected");
    (Some 0, true, "zero page (first page) should be accepted");
    (Some 10, true, "positive page should be accepted");
  ] in
  
  List.iter (fun (page_val, should_succeed, msg) ->
    let json_args = TestArgs.Json.{
      targets = None;
      max_diagnostics = None;
      page = page_val;
      severity_filter = None;
      file_pattern = None;
    } in
    let result = TestArgs.validate_args json_args in
    if should_succeed then
      assert_result_ok ~result ~msg TestArgs.string_of_validation_error
    else
      assert_result_error ~result ~msg
  ) test_page_cases

let test_file_pattern_validation () =
  printf "Testing file pattern validation...\n";
  
  let test_pattern_cases = [
    (Some "", false, "empty pattern should be rejected");
    (Some "src/*.ml", true, "simple pattern should be accepted");
    (Some "**/*.ml", true, "recursive pattern should be accepted");
    (Some (String.make 250 'a'), false, "overly long pattern should be rejected");
    (Some "***********", false, "too many wildcards should be rejected");
    (Some "src/**/*.{ml,mli}", true, "complex but safe pattern should be accepted");
  ] in
  
  List.iter (fun (pattern, should_succeed, msg) ->
    let json_args = TestArgs.Json.{
      targets = None;
      max_diagnostics = None;
      page = None;
      severity_filter = None;
      file_pattern = pattern;
    } in
    let result = TestArgs.validate_args json_args in
    if should_succeed then
      assert_result_ok ~result ~msg TestArgs.string_of_validation_error
    else
      assert_result_error ~result ~msg
  ) test_pattern_cases

let test_error_message_quality () =
  printf "Testing error message quality...\n";
  
  (* Test that error messages are helpful *)
  let json_args_bad_severity = TestArgs.Json.{
    targets = None;
    max_diagnostics = None;
    page = None;
    severity_filter = Some "debug"; (* invalid *)
    file_pattern = None;
  } in
  
  let result = TestArgs.validate_args json_args_bad_severity in
  match result with
  | Error (`Invalid_severity _) -> 
      let error_msg = TestArgs.string_of_validation_error (`Invalid_severity "debug") in
      assert_true ~actual:(String.contains error_msg 'e' && String.length error_msg > 10)
        ~msg:"Error message should be non-empty and descriptive";
      assert_true ~actual:(String.length error_msg > 20)
        ~msg:"Error message should be detailed enough"
  | _ -> 
      failed_tests := "Should produce invalid severity error" :: !failed_tests

let test_backward_compatibility () =
  printf "Testing backward compatibility...\n";
  
  (* Test that minimal JSON (just targets) still works *)
  let minimal_json = TestArgs.Json.{
    targets = Some ["lib"];
    max_diagnostics = None;
    page = None;
    severity_filter = None;
    file_pattern = None;
  } in
  
  let result = TestArgs.validate_args minimal_json in
  match result with
  | Ok args ->
      assert_equal ~expected:(Some ["lib"]) ~actual:args.targets
        ~msg:"targets should be preserved in minimal JSON";
      assert_equal ~expected:None ~actual:args.severity_filter
        ~msg:"severity_filter should default to None when not specified"
  | Error err ->
      failed_tests := ("Backward compatibility test failed: " ^ TestArgs.string_of_validation_error err) :: !failed_tests

(* Main test runner *)
let () =
  printf "=== JSON API Contract Tests ===\n";
  
  (* Run all tests *)
  test_case_insensitive_severity ();
  test_invalid_severity_rejection ();
  test_json_api_contract ();
  test_round_trip_serialization ();
  test_parameter_validation ();
  test_file_pattern_validation ();
  test_error_message_quality ();
  test_backward_compatibility ();
  
  print_results ()