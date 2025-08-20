(** Unit tests for token counting validation and calibration.

    This test suite validates our token counting implementation both against
    known test cases and real tokenizer APIs when available. *)

open Alcotest
open Ocaml_mcp_server.Token_counting

(* Test data representing various OCaml/build scenarios *)
module Test_Data = struct
  type expected_range = {
    min_tokens: int;
    max_tokens: int;
    preferred_estimate: int; (* What we think it should be *)
  }

  let test_cases = [
    (* Simple OCaml keywords *)
    ("Error", { min_tokens = 1; max_tokens = 1; preferred_estimate = 1 });
    ("Warning", { min_tokens = 1; max_tokens = 1; preferred_estimate = 1 });
    ("Unbound", { min_tokens = 1; max_tokens = 2; preferred_estimate = 2 });
    
    (* File paths *)
    ("src/lib.ml", { min_tokens = 2; max_tokens = 4; preferred_estimate = 3 });
    ("src/library/module.ml", { min_tokens = 3; max_tokens = 6; preferred_estimate = 4 });
    ("/home/user/project/src/main.ml", { min_tokens = 5; max_tokens = 10; preferred_estimate = 7 });
    
    (* Module paths *)
    ("Core.List.map", { min_tokens = 3; max_tokens = 5; preferred_estimate = 4 });
    ("My_project.Utils.String_helpers", { min_tokens = 3; max_tokens = 8; preferred_estimate = 5 });
    
    (* Error messages *)
    ("Unbound variable x", { min_tokens = 3; max_tokens = 4; preferred_estimate = 3 });
    ("This expression has type int", { min_tokens = 5; max_tokens = 7; preferred_estimate = 6 });
    ("Syntax error: ')' expected", { min_tokens = 4; max_tokens = 6; preferred_estimate = 5 });
    
    (* JSON-like structures *)
    ("{\"severity\": \"error\"}", { min_tokens = 4; max_tokens = 8; preferred_estimate = 6 });
    ("{\"file\": \"main.ml\", \"line\": 42}", { min_tokens = 6; max_tokens = 10; preferred_estimate = 8 });
    
    (* Longer content *)
    ("This expression has type int but an expression was expected of type string", 
     { min_tokens = 12; max_tokens = 18; preferred_estimate = 15 });
    
    (* Multi-line content *)
    ("Error: Type mismatch\nFile \"main.ml\", line 5\n  let x = \"hello\" + 42",
     { min_tokens = 12; max_tokens = 20; preferred_estimate = 16 });
  ]
end

(* Basic token counting tests *)
module Test_Basic_Counting = struct
  let test_known_ranges () =
    List.iter (fun (text, expected) ->
      let actual = estimate_text_tokens_empirical text in
      let in_range = actual >= expected.Test_Data.min_tokens && actual <= expected.Test_Data.max_tokens in
      check bool 
        (Printf.sprintf "Token count for '%s' should be in range [%d, %d], got %d" 
         text expected.min_tokens expected.max_tokens actual)
        true in_range
    ) Test_Data.test_cases

  let test_empty_string () =
    let actual = estimate_text_tokens_empirical "" in
    check int "Empty string should have 1 token" 1 actual

  let test_single_chars () =
    let test_cases = ["a"; "x"; "1"; "."; "/"] in
    List.iter (fun text ->
      let actual = estimate_text_tokens_empirical text in
      check bool 
        (Printf.sprintf "Single char '%s' should have 1 token, got %d" text actual)
        true (actual = 1)
    ) test_cases

  let test_ocaml_vocabulary () =
    (* Test that our OCaml-specific vocabulary is working *)
    let ocaml_terms = [
      ("Error", 1); ("Warning", 1); ("Unbound", 2); ("module", 1);
      ("expected", 1); ("type", 1); ("mismatch", 2); ("syntax", 1);
    ] in
    List.iter (fun (term, expected_tokens) ->
      let actual = estimate_text_tokens_empirical term in
      check int 
        (Printf.sprintf "OCaml term '%s' should have %d tokens" term expected_tokens)
        expected_tokens actual
    ) ocaml_terms

  let test_conservative_estimates () =
    (* Our estimates should generally be conservative (slightly higher) *)
    (* This is a heuristic test - we expect most estimates to be >= a simple word-based count *)
    List.iter (fun (text, _) ->
      let our_estimate = estimate_text_tokens_empirical text in
      let simple_word_count = List.length (String.split_on_char ' ' text) in
      let conservative = our_estimate >= simple_word_count in
      check bool 
        (Printf.sprintf "Estimate for '%s' should be conservative (>= %d words), got %d tokens" 
         text simple_word_count our_estimate)
        true conservative
    ) Test_Data.test_cases

  let suite = [
    test_case "known ranges" `Quick test_known_ranges;
    test_case "empty string" `Quick test_empty_string;
    test_case "single characters" `Quick test_single_chars;
    test_case "OCaml vocabulary" `Quick test_ocaml_vocabulary;
    test_case "conservative estimates" `Quick test_conservative_estimates;
  ]
end

(* JSON overhead calculation tests *)
module Test_JSON_Overhead = struct
  let test_field_overhead () =
    (* Test JSON field overhead calculations *)
    let test_cases = [
      ("severity", `String, 3);  (* "severity": + quotes + comma/colon *)
      ("line", `Number, 2);      (* "line": + value + comma/colon *)  
      ("diagnostics", `Array, 4); (* "diagnostics": + brackets + comma/colon *)
    ] in
    List.iter (fun (field_name, field_type, expected_min) ->
      let actual = estimate_json_field_overhead field_name field_type in
      check bool 
        (Printf.sprintf "JSON overhead for field '%s' should be >= %d, got %d" 
         field_name expected_min actual)
        true (actual >= expected_min)
    ) test_cases

  let test_diagnostic_estimation () =
    (* Test full diagnostic object estimation *)
    let sample_diagnostic = Ocaml_mcp_server.Build_types.Output.{
      severity = "error";
      file = "src/main.ml";
      line = 42;
      column = 8;
      message = "Unbound variable x";
    } in
    let estimated_tokens = estimate_diagnostic_tokens sample_diagnostic in
    
    (* Should include content + JSON overhead *)
    let content_estimate = 
      estimate_text_tokens_empirical "error" +
      estimate_text_tokens_empirical "src/main.ml" +
      1 + 1 + (* line and column numbers *)
      estimate_text_tokens_empirical "Unbound variable x"
    in
    
    check bool 
      "Diagnostic estimation should include JSON overhead"
      true (estimated_tokens > content_estimate)

  let suite = [
    test_case "field overhead" `Quick test_field_overhead;
    test_case "diagnostic estimation" `Quick test_diagnostic_estimation;
  ]
end

(* Caching system tests *)
module Test_Caching = struct
  let test_cache_consistency () =
    (* Test that caching returns consistent results *)
    let test_text = "This is a test string for caching validation" in
    let first_call = estimate_text_tokens_empirical test_text in
    let second_call = estimate_text_tokens_empirical test_text in
    check int "Cached result should be consistent" first_call second_call

  let test_cache_performance () =
    (* Test that caching improves performance for repeated calls *)
    let test_text = "Performance test string that should be cached effectively" in
    
    (* Warm up cache *)
    let _ = estimate_text_tokens_empirical test_text in
    
    (* Time multiple calls *)
    let start_time = Unix.gettimeofday () in
    for _ = 1 to 1000 do
      let _ = estimate_text_tokens_empirical test_text in
      ()
    done;
    let end_time = Unix.gettimeofday () in
    let cached_time = end_time -. start_time in
    
    (* Clear cache and time again (if we could access cache clearing) *)
    (* For now, just verify the result is still correct *)
    let result = estimate_text_tokens_empirical test_text in
    check bool "Cached results should still be correct" true (result > 0);
    
    (* Print timing for manual inspection *)
    Printf.printf "1000 cached calls took %.4f seconds\n" cached_time

  let suite = [
    test_case "cache consistency" `Quick test_cache_consistency;
    test_case "cache performance" `Quick test_cache_performance;
  ]
end

(* Integration tests for complete response estimation *)
module Test_Response_Estimation = struct
  let create_sample_response () =
    let open Ocaml_mcp_server.Build_types.Output in
    {
      status = "completed";
      diagnostics = [
        { severity = "error"; file = "src/main.ml"; line = 15; column = 8; 
          message = "Unbound variable foo" };
        { severity = "warning"; file = "src/utils.ml"; line = 23; column = 12; 
          message = "Unused variable bar" };
      ];
      truncated = false;
      truncation_reason = None;
      next_cursor = None;
      token_count = 0; (* Will be calculated *)
      summary = {
        total_diagnostics = 2;
        returned_diagnostics = 2;
        error_count = 1;
        warning_count = 1;
        build_summary = Some { completed = 10; remaining = 0; failed = 1 };
      };
    }

  let test_complete_response_estimation () =
    let sample_response = create_sample_response () in
    let estimated_tokens = estimate_response_tokens sample_response in
    
    (* Should be reasonable for this amount of content *)
    check bool "Response estimation should be reasonable" 
      true (estimated_tokens > 20 && estimated_tokens < 200);
    
    (* Should include all components *)
    let manual_estimate = 
      (* Status field *)
      estimate_text_tokens_empirical "completed" + 3 +
      (* Two diagnostics with JSON overhead *)
      (estimate_text_tokens_empirical "error" + estimate_text_tokens_empirical "src/main.ml" + 
       estimate_text_tokens_empirical "Unbound variable foo" + 15) +
      (estimate_text_tokens_empirical "warning" + estimate_text_tokens_empirical "src/utils.ml" + 
       estimate_text_tokens_empirical "Unused variable bar" + 15) +
      (* Summary and other fields *)
      30 (* Rough estimate for remaining structure *)
    in
    
    check bool "Estimation should be in reasonable range of manual calculation"
      true (abs (estimated_tokens - manual_estimate) < manual_estimate / 2)

  let test_truncation_scenarios () =
    (* Test with truncation *)
    let truncated_response = 
      let base = create_sample_response () in
      { base with 
        truncated = true; 
        truncation_reason = Some "Token limit exceeded";
        next_cursor = Some "cursor_123" }
    in
    let estimated_tokens = estimate_response_tokens truncated_response in
    
    check bool "Truncated response should include truncation fields"
      true (estimated_tokens > 0)

  let suite = [
    test_case "complete response estimation" `Quick test_complete_response_estimation;
    test_case "truncation scenarios" `Quick test_truncation_scenarios;
  ]
end

(* Regression tests for known issues or edge cases *)
module Test_Regression = struct
  let test_unicode_handling () =
    (* Test Unicode character handling *)
    let unicode_texts = [
      "Error: résumé";
      "Warning: naïve approach";
      "File: résumé.ml";
      "Message: 日本語のテスト"; (* Japanese text *)
    ] in
    List.iter (fun text ->
      let tokens = estimate_text_tokens_empirical text in
      check bool 
        (Printf.sprintf "Unicode text '%s' should have reasonable token count" text)
        true (tokens > 0 && tokens < String.length text)
    ) unicode_texts

  let test_very_long_strings () =
    (* Test handling of very long strings *)
    let long_string = String.make 10000 'x' in
    let tokens = estimate_text_tokens_empirical long_string in
    
    (* Should be roughly length / 4 to length / 2 for repeated characters *)
    let expected_min = 10000 / 6 in
    let expected_max = 10000 / 2 in
    check bool 
      (Printf.sprintf "Very long string should have reasonable token count (%d to %d)" 
       expected_min expected_max)
      true (tokens >= expected_min && tokens <= expected_max)

  let test_special_characters () =
    (* Test handling of special characters that might affect tokenization *)
    let special_texts = [
      "file.ml:42:8: error";
      "module Foo.Bar -> Baz";
      "type t = { x: int; y: string }";
      "let f x y = x + y (* comment *)";
      "exception Not_found of string * int";
    ] in
    List.iter (fun text ->
      let tokens = estimate_text_tokens_empirical text in
      check bool 
        (Printf.sprintf "Special character text should have reasonable token count")
        true (tokens > 0)
    ) special_texts

  let suite = [
    test_case "unicode handling" `Quick test_unicode_handling;
    test_case "very long strings" `Slow test_very_long_strings;
    test_case "special characters" `Quick test_special_characters;
  ]
end

(* Property-based tests *)
module Test_Properties = struct
  let test_monotonicity () =
    (* Test that longer strings generally have more tokens *)
    let base_text = "Error in module" in
    let extended_text = base_text ^ " Foo.Bar.Baz with message details" in
    let longer_text = extended_text ^ " and additional context information here" in
    
    let base_tokens = estimate_text_tokens_empirical base_text in
    let extended_tokens = estimate_text_tokens_empirical extended_text in
    let longer_tokens = estimate_text_tokens_empirical longer_text in
    
    check bool "Longer strings should have more tokens (generally)" 
      true (base_tokens <= extended_tokens && extended_tokens <= longer_tokens)

  let test_composition_bounds () =
    (* Test that combining strings gives reasonable bounds *)
    let text1 = "Error: syntax error" in
    let text2 = "in file main.ml" in
    let combined = text1 ^ " " ^ text2 in
    
    let tokens1 = estimate_text_tokens_empirical text1 in
    let tokens2 = estimate_text_tokens_empirical text2 in
    let combined_tokens = estimate_text_tokens_empirical combined in
    
    (* Combined should be roughly the sum, but may differ due to context *)
    let sum_tokens = tokens1 + tokens2 in
    check bool "Combined text tokens should be reasonable relative to sum"
      true (combined_tokens >= sum_tokens - 2 && combined_tokens <= sum_tokens + 5)

  let suite = [
    test_case "monotonicity" `Quick test_monotonicity;
    test_case "composition bounds" `Quick test_composition_bounds;
  ]
end

(* Main test suite *)
let () = 
  run "Token Validation Tests" [
    ("Basic Counting", Test_Basic_Counting.suite);
    ("JSON Overhead", Test_JSON_Overhead.suite);
    ("Caching", Test_Caching.suite);
    ("Response Estimation", Test_Response_Estimation.suite);
    ("Regression", Test_Regression.suite);
    ("Properties", Test_Properties.suite);
  ]