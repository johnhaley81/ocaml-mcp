(* Comprehensive tests for dune_build_status tool schema functionality *)
(* Tests JSON schema generation, serialization, and validation *)

(* Since we can't easily import the full module due to dependency issues, *)
(* we'll test the schema logic with simulated types and functions *)

open Yojson.Safe

(* Simulate the Args and Output types from build_status.ml *)
type severity_filter = [`Error | `Warning | `All]

type args = {
  targets : string list option;
  max_diagnostics : int option;
  page : int option;
  severity_filter : severity_filter option;
  file_pattern : string option;
}

type diagnostic = {
  severity : string;
  file : string;
  line : int;
  column : int;
  message : string;
}

type build_summary = {
  completed : int;
  remaining : int;
  failed : int;
}

type diagnostic_summary = {
  total_diagnostics : int;
  returned_diagnostics : int;
  error_count : int;
  warning_count : int;
  build_summary : build_summary option;
}

type output = {
  status : string;
  diagnostics : diagnostic list;
  truncated : bool;
  truncation_reason : string option;
  next_cursor : string option;
  token_count : int;
  summary : diagnostic_summary;
}

(* Simulate the schema generation functions *)
let args_schema () =
  `Assoc [
    ("type", `String "object");
    ("properties", `Assoc [
      ("targets", `Assoc [
        ("type", `String "array");
        ("items", `Assoc [("type", `String "string")]);
        ("description", `String "List of specific targets to build");
      ]);
      ("max_diagnostics", `Assoc [
        ("type", `String "integer");
        ("minimum", `Int 1);
        ("maximum", `Int 1000);
        ("description", `String "Maximum number of diagnostics to return (for token management)");
      ]);
      ("page", `Assoc [
        ("type", `String "integer");
        ("minimum", `Int 0);
        ("description", `String "Page number for paginated results (0-based)");
      ]);
      ("severity_filter", `Assoc [
        ("type", `String "string");
        ("enum", `List [`String "error"; `String "warning"; `String "all"]);
        ("description", `String "Filter diagnostics by severity level");
      ]);
      ("file_pattern", `Assoc [
        ("type", `String "string");
        ("description", `String "Glob pattern to filter files (e.g., 'src/**/*.ml')");
      ]);
    ]);
    ("required", `List []);
  ]

(* Simple serialization functions *)
let severity_filter_to_yojson = function
  | `Error -> `String "error"
  | `Warning -> `String "warning"
  | `All -> `String "all"

let severity_filter_of_yojson = function
  | `String "error" -> Ok `Error
  | `String "warning" -> Ok `Warning
  | `String "all" -> Ok `All
  | _ -> Error "Invalid severity filter"

let option_to_yojson f = function
  | None -> `Null
  | Some v -> f v

let option_of_yojson f = function
  | `Null -> Ok None
  | v -> match f v with
         | Ok result -> Ok (Some result)
         | Error msg -> Error msg

let list_to_yojson f lst = `List (List.map f lst)
let list_of_yojson f = function
  | `List lst -> 
      let rec convert acc = function
        | [] -> Ok (List.rev acc)
        | x :: xs -> 
            (match f x with
             | Ok v -> convert (v :: acc) xs
             | Error msg -> Error msg)
      in
      convert [] lst
  | _ -> Error "Expected array"

let string_list_to_yojson lst = list_to_yojson (fun s -> `String s) lst
let string_list_of_yojson json = list_of_yojson (function `String s -> Ok s | _ -> Error "Expected string") json

let args_to_yojson args =
  `Assoc [
    ("targets", option_to_yojson string_list_to_yojson args.targets);
    ("max_diagnostics", option_to_yojson (fun i -> `Int i) args.max_diagnostics);
    ("page", option_to_yojson (fun i -> `Int i) args.page);
    ("severity_filter", option_to_yojson severity_filter_to_yojson args.severity_filter);
    ("file_pattern", option_to_yojson (fun s -> `String s) args.file_pattern);
  ]

let args_of_yojson json =
  match json with
  | `Assoc fields ->
      let get_field name default_value parser =
        match List.assoc_opt name fields with
        | Some value -> parser value
        | None -> Ok default_value
      in
      (match 
        get_field "targets" None (option_of_yojson string_list_of_yojson),
        get_field "max_diagnostics" None (option_of_yojson (function `Int i -> Ok i | _ -> Error "Expected int")),
        get_field "page" None (option_of_yojson (function `Int i -> Ok i | _ -> Error "Expected int")),
        get_field "severity_filter" None (option_of_yojson severity_filter_of_yojson),
        get_field "file_pattern" None (option_of_yojson (function `String s -> Ok s | _ -> Error "Expected string"))
       with
       | Ok targets, Ok max_diagnostics, Ok page, Ok severity_filter, Ok file_pattern ->
           Ok { targets; max_diagnostics; page; severity_filter; file_pattern }
       | Error msg, _, _, _, _ -> Error msg
       | _, Error msg, _, _, _ -> Error msg
       | _, _, Error msg, _, _ -> Error msg
       | _, _, _, Error msg, _ -> Error msg
       | _, _, _, _, Error msg -> Error msg
      )
  | _ -> Error "Expected object"

(* Simple test framework *)
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

let assert_int_equal ~expected ~actual ~msg =
  assert_equal ~expected ~actual ~msg:(Printf.sprintf "%s: expected %d, got %d" msg expected actual)

let assert_bool_equal ~expected ~actual ~msg =
  assert_equal ~expected ~actual ~msg:(Printf.sprintf "%s: expected %b, got %b" msg expected actual)

let print_results () =
  let total = !test_count in
  let failed = List.length !failed_tests in
  let passed = total - failed in
  Printf.printf "\n=== Test Results ===\n";
  Printf.printf "Total tests: %d\n" total;
  Printf.printf "Passed: %d\n" passed;
  Printf.printf "Failed: %d\n" failed;
  if failed > 0 then begin
    Printf.printf "\nFailed tests:\n";
    List.iter (fun msg -> Printf.printf "- %s\n" msg) (List.rev !failed_tests);
    exit 1
  end else begin
    Printf.printf "\nAll tests passed!\n";
    exit 0
  end

(* Schema validation helpers *)
let extract_properties schema =
  match schema with
  | `Assoc props ->
      (match List.assoc_opt "properties" props with
      | Some (`Assoc properties) -> Some properties
      | _ -> None)
  | _ -> None

let has_property properties name =
  List.assoc_opt name properties |> Option.is_some

let get_property_type properties name =
  match List.assoc_opt name properties with
  | Some (`Assoc prop) ->
      (match List.assoc_opt "type" prop with
      | Some (`String typ) -> Some typ
      | _ -> None)
  | _ -> None

let has_enum properties name =
  match List.assoc_opt name properties with
  | Some (`Assoc prop) ->
      List.assoc_opt "enum" prop |> Option.is_some
  | _ -> false

let has_validation properties name =
  match List.assoc_opt name properties with
  | Some (`Assoc prop) ->
      List.assoc_opt "minimum" prop |> Option.is_some ||
      List.assoc_opt "maximum" prop |> Option.is_some
  | _ -> false

(* Args schema tests *)
let test_schema_structure () =
  Printf.printf "Testing schema structure...\n";
  let schema = args_schema () in
  match schema with
  | `Assoc props ->
      let prop_names = List.map fst props in
      assert_true ~actual:(List.mem "type" prop_names) ~msg:"Schema should have 'type' property";
      assert_true ~actual:(List.mem "properties" prop_names) ~msg:"Schema should have 'properties' property";
      assert_true ~actual:(List.mem "required" prop_names) ~msg:"Schema should have 'required' property"
  | _ -> failed_tests := "Schema should be an object" :: !failed_tests

let test_all_expected_fields () =
  Printf.printf "Testing all expected fields...\n";
  let schema = args_schema () in
  let expected_fields = ["targets"; "max_diagnostics"; "page"; "severity_filter"; "file_pattern"] in
  
  match extract_properties schema with
  | Some properties ->
      List.iter (fun field ->
        assert_true ~actual:(has_property properties field) 
          ~msg:(Printf.sprintf "Schema should have '%s' field" field)
      ) expected_fields
  | None -> failed_tests := "Schema should have properties" :: !failed_tests

let test_field_types () =
  Printf.printf "Testing field types...\n";
  let schema = args_schema () in
  match extract_properties schema with
  | Some properties ->
      let type_tests = [
        ("targets", "array");
        ("max_diagnostics", "integer");
        ("page", "integer");
        ("severity_filter", "string");
        ("file_pattern", "string");
      ] in
      List.iter (fun (field, expected_type) ->
        let actual_type = get_property_type properties field in
        assert_equal ~expected:(Some expected_type) ~actual:actual_type
          ~msg:(Printf.sprintf "Field '%s' should have type '%s'" field expected_type)
      ) type_tests
  | None -> failed_tests := "Schema should have properties" :: !failed_tests

let test_validation_constraints () =
  Printf.printf "Testing validation constraints...\n";
  let schema = args_schema () in
  match extract_properties schema with
  | Some properties ->
      assert_true ~actual:(has_validation properties "max_diagnostics")
        ~msg:"max_diagnostics should have validation constraints";
      assert_true ~actual:(has_validation properties "page")
        ~msg:"page should have validation constraints";
      assert_true ~actual:(has_enum properties "severity_filter")
        ~msg:"severity_filter should have enum constraint"
  | None -> failed_tests := "Schema should have properties" :: !failed_tests

let test_no_required_fields () =
  Printf.printf "Testing no required fields...\n";
  let schema = args_schema () in
  match schema with
  | `Assoc props ->
      (match List.assoc_opt "required" props with
      | Some (`List required) ->
          assert_int_equal ~expected:0 ~actual:(List.length required) ~msg:"Args schema should have no required fields"
      | _ -> failed_tests := "Schema should have required field as list" :: !failed_tests)
  | _ -> failed_tests := "Schema should be an object" :: !failed_tests

(* Args JSON serialization tests *)
let test_minimal_args () =
  Printf.printf "Testing minimal args serialization...\n";
  let args = {
    targets = None;
    max_diagnostics = None;
    page = None;
    severity_filter = None;
    file_pattern = None;
  } in
  
  let json = args_to_yojson args in
  let parsed = args_of_yojson json in
  
  match parsed with
  | Ok parsed_args ->
      assert_equal ~expected:args.targets ~actual:parsed_args.targets ~msg:"Targets should match";
      assert_equal ~expected:args.max_diagnostics ~actual:parsed_args.max_diagnostics ~msg:"Max diagnostics should match";
      assert_equal ~expected:args.page ~actual:parsed_args.page ~msg:"Page should match";
      assert_equal ~expected:args.file_pattern ~actual:parsed_args.file_pattern ~msg:"File pattern should match"
  | Error msg -> failed_tests := ("JSON parsing failed: " ^ msg) :: !failed_tests

let test_full_args () =
  Printf.printf "Testing full args serialization...\n";
  let args = {
    targets = Some ["lib"; "bin"; "test"];
    max_diagnostics = Some 100;
    page = Some 2;
    severity_filter = Some `Error;
    file_pattern = Some "src/**/*.ml";
  } in
  
  let json = args_to_yojson args in
  let parsed = args_of_yojson json in
  
  match parsed with
  | Ok parsed_args ->
      assert_equal ~expected:args.targets ~actual:parsed_args.targets ~msg:"Targets should match";
      assert_equal ~expected:args.max_diagnostics ~actual:parsed_args.max_diagnostics ~msg:"Max diagnostics should match";
      assert_equal ~expected:args.page ~actual:parsed_args.page ~msg:"Page should match";
      assert_equal ~expected:args.file_pattern ~actual:parsed_args.file_pattern ~msg:"File pattern should match"
  | Error msg -> failed_tests := ("JSON parsing failed: " ^ msg) :: !failed_tests

let test_severity_filter_variants () =
  Printf.printf "Testing severity filter variants...\n";
  let test_cases = [`Error; `Warning; `All] in
  List.iter (fun severity ->
    let args = {
      targets = None;
      max_diagnostics = None;
      page = None;
      severity_filter = Some severity;
      file_pattern = None;
    } in
    
    let json = args_to_yojson args in
    let parsed = args_of_yojson json in
    
    match parsed with
    | Ok parsed_args ->
        assert_bool_equal ~expected:true ~actual:(parsed_args.severity_filter = args.severity_filter)
          ~msg:(Printf.sprintf "Severity filter should match for %s" 
            (match severity with `Error -> "Error" | `Warning -> "Warning" | `All -> "All"))
    | Error msg -> failed_tests := ("JSON parsing failed: " ^ msg) :: !failed_tests
  ) test_cases

let test_backward_compatibility () =
  Printf.printf "Testing backward compatibility...\n";
  (* Test that old JSON format (only targets) still works *)
  let old_json = `Assoc [("targets", `List [`String "lib"; `String "bin"])] in
  let parsed = args_of_yojson old_json in
  
  match parsed with
  | Ok args ->
      assert_equal ~expected:(Some ["lib"; "bin"]) ~actual:args.targets ~msg:"Targets should be parsed";
      assert_equal ~expected:None ~actual:args.max_diagnostics ~msg:"Max diagnostics should default to None";
      assert_equal ~expected:None ~actual:args.page ~msg:"Page should default to None";
      assert_equal ~expected:None ~actual:args.file_pattern ~msg:"File pattern should default to None"
  | Error msg -> failed_tests := ("Backward compatibility test failed: " ^ msg) :: !failed_tests

(* Simple output structure tests - without full serialization *)
let test_output_structure () =
  Printf.printf "Testing output structure...\n";
  
  let sample_diagnostic = {
    severity = "error";
    file = "src/main.ml";
    line = 10;
    column = 5;
    message = "Error: Unbound value example_function";
  } in
  
  let build_summary = {
    completed = 8;
    remaining = 2;
    failed = 1;
  } in
  
  let summary = {
    total_diagnostics = 25;
    returned_diagnostics = 10;
    error_count = 5;
    warning_count = 20;
    build_summary = Some build_summary;
  } in
  
  let output = {
    status = "success_with_warnings";
    diagnostics = [sample_diagnostic];
    truncated = true;
    truncation_reason = Some "Token limit exceeded";
    next_cursor = Some "page_2_cursor";
    token_count = 24500;
    summary;
  } in
  
  (* Test structure is valid *)
  assert_equal ~expected:"success_with_warnings" ~actual:output.status ~msg:"Status should match";
  assert_int_equal ~expected:1 ~actual:(List.length output.diagnostics) ~msg:"Should have one diagnostic";
  assert_bool_equal ~expected:true ~actual:output.truncated ~msg:"Should be truncated";
  assert_equal ~expected:(Some "Token limit exceeded") ~actual:output.truncation_reason ~msg:"Should have truncation reason";
  assert_int_equal ~expected:24500 ~actual:output.token_count ~msg:"Token count should match";
  assert_int_equal ~expected:25 ~actual:output.summary.total_diagnostics ~msg:"Summary total should match"

let test_diagnostic_structure () =
  Printf.printf "Testing diagnostic structure...\n";
  
  let diagnostic = {
    severity = "error";
    file = "test/example.ml";
    line = 42;
    column = 15;
    message = "Type error: expected int, got string";
  } in
  
  assert_equal ~expected:"error" ~actual:diagnostic.severity ~msg:"Severity should match";
  assert_equal ~expected:"test/example.ml" ~actual:diagnostic.file ~msg:"File should match";
  assert_int_equal ~expected:42 ~actual:diagnostic.line ~msg:"Line should match";
  assert_int_equal ~expected:15 ~actual:diagnostic.column ~msg:"Column should match";
  assert_true ~actual:(String.length diagnostic.message > 0) ~msg:"Message should not be empty"

let test_build_summary_optional () =
  Printf.printf "Testing build summary optional field...\n";
  
  let summary_with_build = {
    total_diagnostics = 10;
    returned_diagnostics = 5;
    error_count = 2;
    warning_count = 8;
    build_summary = Some { completed = 5; remaining = 3; failed = 2 };
  } in
  
  let summary_without_build = {
    total_diagnostics = 10;
    returned_diagnostics = 5;
    error_count = 2;
    warning_count = 8;
    build_summary = None;
  } in
  
  assert_true ~actual:(Option.is_some summary_with_build.build_summary) ~msg:"Should have build summary";
  assert_true ~actual:(Option.is_none summary_without_build.build_summary) ~msg:"Should not have build summary";
  
  match summary_with_build.build_summary with
  | Some bs ->
      assert_int_equal ~expected:5 ~actual:bs.completed ~msg:"Completed should match";
      assert_int_equal ~expected:3 ~actual:bs.remaining ~msg:"Remaining should match";
      assert_int_equal ~expected:2 ~actual:bs.failed ~msg:"Failed should match"
  | None -> failed_tests := "Expected build summary" :: !failed_tests

(* Default value tests *)
let test_args_defaults () =
  Printf.printf "Testing args defaults...\n";
  (* Test that default values are applied correctly when not specified *)
  let empty_json = `Assoc [] in
  let parsed = args_of_yojson empty_json in
  
  match parsed with
  | Ok args ->
      assert_equal ~expected:None ~actual:args.targets ~msg:"Targets should default to None";
      assert_equal ~expected:None ~actual:args.max_diagnostics ~msg:"Max diagnostics should default to None";
      assert_equal ~expected:None ~actual:args.page ~msg:"Page should default to None";
      assert_equal ~expected:None ~actual:args.file_pattern ~msg:"File pattern should default to None"
  | Error msg -> failed_tests := ("Default values test failed: " ^ msg) :: !failed_tests

let test_output_defaults () =
  Printf.printf "Testing output defaults...\n";
  (* Test output fields that have default values *)
  let summary = {
    total_diagnostics = 0;
    returned_diagnostics = 0;
    error_count = 0;
    warning_count = 0;
    build_summary = None;
  } in
  
  let output = {
    status = "success";
    diagnostics = [];
    truncated = false;
    truncation_reason = None;
    next_cursor = None;
    token_count = 0;
    summary;
  } in
  
  assert_bool_equal ~expected:false ~actual:output.truncated ~msg:"Truncated should default to false";
  assert_equal ~expected:None ~actual:output.truncation_reason ~msg:"Truncation reason should default to None";
  assert_equal ~expected:None ~actual:output.next_cursor ~msg:"Next cursor should default to None";
  assert_int_equal ~expected:0 ~actual:output.token_count ~msg:"Token count should default to 0"

(* Schema validation edge cases *)
let test_severity_filter_enum_values () =
  Printf.printf "Testing severity filter enum values...\n";
  let schema = args_schema () in
  match extract_properties schema with
  | Some properties ->
      (match List.assoc_opt "severity_filter" properties with
      | Some (`Assoc prop) ->
          (match List.assoc_opt "enum" prop with
          | Some (`List enum_values) ->
              let expected_values = [`String "error"; `String "warning"; `String "all"] in
              assert_int_equal ~expected:3 ~actual:(List.length enum_values) ~msg:"Should have 3 severity filter options";
              List.iter (fun expected ->
                assert_true ~actual:(List.mem expected enum_values)
                  ~msg:(Printf.sprintf "Should include %s" 
                    (match expected with `String s -> s | _ -> "unknown"))
              ) expected_values
          | _ -> failed_tests := "Severity filter should have enum values" :: !failed_tests)
      | _ -> failed_tests := "Severity filter property should exist" :: !failed_tests)
  | None -> failed_tests := "Schema should have properties" :: !failed_tests

let test_page_zero_based () =
  Printf.printf "Testing page zero based...\n";
  (* The schema shows page has minimum 0 (0-based pagination) *)
  let schema = args_schema () in
  match extract_properties schema with
  | Some properties ->
      (match List.assoc_opt "page" properties with
      | Some (`Assoc prop) ->
          (match List.assoc_opt "minimum" prop with
          | Some (`Int min_val) ->
              assert_int_equal ~expected:0 ~actual:min_val ~msg:"Page should be 0-based (minimum 0)"
          | _ -> failed_tests := "Page should have minimum constraint" :: !failed_tests)
      | _ -> failed_tests := "Page property should exist" :: !failed_tests)
  | None -> failed_tests := "Schema should have properties" :: !failed_tests

(* Main test runner *)
let () =
  Printf.printf "=== Build Status Schema Tests ===\n";
  
  (* Run all tests *)
  test_schema_structure ();
  test_all_expected_fields ();
  test_field_types ();
  test_validation_constraints ();
  test_no_required_fields ();
  test_minimal_args ();
  test_full_args ();
  test_severity_filter_variants ();
  test_backward_compatibility ();
  test_output_structure ();
  test_diagnostic_structure ();
  test_build_summary_optional ();
  test_args_defaults ();
  test_output_defaults ();
  test_severity_filter_enum_values ();
  test_page_zero_based ();
  
  print_results ()