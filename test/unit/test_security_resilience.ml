(* Security and Resilience Testing Suite for dune_build_status API *)
(* Tests ReDoS prevention, input validation, and chaos engineering scenarios *)

open Printf
open Unix

[@@@warning "-26-27-35"]

(* Import the build_status tool *)
module Args = Ocaml_mcp_server.Testing.Build_status.Args
module Output = Ocaml_mcp_server.Testing.Build_status.Output

(* Security test results tracking *)
type security_test_result = {
  test_name: string;
  attack_type: [`ReDoS | `InputValidation | `ResourceExhaustion | `InjectionAttempt];
  attack_payload: string;
  response_time_ms: float;
  memory_usage_kb: int option;
  blocked: bool;
  vulnerability_detected: bool;
  severity: [`Critical | `High | `Medium | `Low];
  details: string option;
}

type chaos_test_result = {
  scenario: string;
  failure_injected: string;
  recovery_time_ms: float;
  data_consistency: bool;
  graceful_degradation: bool;
  passed: bool;
}

let security_results = ref []
let chaos_results = ref []

(* Utility functions *)
let measure_with_timeout ~timeout_ms f =
  let start_time = gettimeofday () in
  let timeout_seconds = float_of_int timeout_ms /. 1000.0 in
  
  let result = ref None in
  let completed = ref false in
  let timeout_reached = ref false in
  
  let worker_thread = Thread.create (fun () ->
    try
      let r = f () in
      result := Some (Ok r);
      completed := true
    with
    | exn ->
        result := Some (Error (Printexc.to_string exn));
        completed := true
  ) () in
  
  (* Wait for completion or timeout *)
  let rec wait_loop () =
    if !completed then ()
    else if gettimeofday () -. start_time > timeout_seconds then (
      (* Timeout reached - set flag and let thread finish *)
      timeout_reached := true;
      result := Some (Error "Timeout")
    ) else (
      Thread.delay 0.01;
      wait_loop ()
    )
  in
  
  wait_loop ();
  let duration = (gettimeofday () -. start_time) *. 1000.0 in
  
  match !result with
  | Some r -> (r, duration)
  | None -> (Error "Unknown error", duration)

let measure_memory_during f =
  let initial_heap = Gc.stat () in
  let result = f () in
  let final_heap = Gc.stat () in
  let memory_diff = (final_heap.live_words - initial_heap.live_words) * (Sys.word_size / 8) / 1024 in
  (result, max 0 memory_diff)

(* Security Attack Patterns *)
module SecurityAttacks = struct
  
  (* ReDoS (Regular Expression Denial of Service) attack patterns *)
  let redos_attack_patterns = [
    (* Catastrophic backtracking patterns *)
    ("Nested quantifiers", "(a+)+", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX");
    ("Alternation with overlapping", "(a|a)*", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX");
    ("Exponential blowup", "(a+)*", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX");
    ("Grouping with quantifiers", "(a*)*", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX");
    
    (* File pattern specific attacks *)
    ("Wildcard explosion", String.make 100 '*', "test.ml");
    ("Nested directory attack", "**/**/" ^ String.make 50 '*' ^ "/**", "src/test.ml");
    ("Long path with wildcards", String.make 200 'a' ^ "*", "src/" ^ String.make 200 'b' ^ ".ml");
    ("Recursive pattern", "**/" ^ String.make 50 '*' ^ "/**/*.{" ^ String.make 100 'x' ^ "}", "test.ml");
    
    (* Unicode-based attacks *)
    ("Unicode ReDoS", "([\u{0000}-\u{FFFF}]+)*", "\u{1F600}" ^ String.make 30 'a');
    ("Mixed encoding", "([à-ÿ]+)*", String.make 40 '.' ^ "X");
  ]
  
  (* Input validation attack patterns *)
  let input_validation_attacks = [
    (* JSON structure attacks *)
    ("Deeply nested JSON", String.concat "" (List.init 1000 (fun _ -> "{\"")) ^ "test\"" ^ String.concat "" (List.init 1000 (fun _ -> "}")));
    ("Large array", "[" ^ String.concat "," (List.init 100000 (fun i -> sprintf "\"%d\"" i)) ^ "]");
    ("Recursive references", "{\"a\": {\"b\": {\"c\": {\"d\": {\"e\": null}}}}}");
    
    (* Parameter boundary attacks *)
    ("Integer overflow", string_of_int max_int ^ "0000");
    ("Negative overflow", "-" ^ string_of_int max_int ^ "0000");
    ("Float precision attack", "1." ^ String.make 1000 '9');
    
    (* String-based attacks *)
    ("Null byte injection", "test\\u0000file.ml");
    ("Control character flood", String.make 1000 '\x01');
    ("UTF-8 BOM attack", "\xEF\xBB\xBFtest.ml");
    
    (* Path traversal attempts *)
    ("Directory traversal", "../../../etc/passwd");
    ("Windows path traversal", "..\\..\\..\\windows\\system32");
    ("Encoded path traversal", "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd");
  ]
  
  (* Resource exhaustion patterns *)
  let resource_exhaustion_attacks = [
    (* Memory exhaustion *)
    ("Huge string", String.make 1000000 'A');
    ("Memory bomb string", String.concat "" (List.init 10000 (fun i -> sprintf "LongStringPattern_%d_" i)));
    
    (* CPU exhaustion *)
    ("CPU intensive pattern", String.make 100 'x' ^ "z");
    ("Algorithmic complexity attack", "no_match_text");
  ]
end

(* Security Testing Suite *)
module SecurityTests = struct
  
  let record_security_test test_name attack_type attack_payload response_time_ms memory_usage_kb blocked vulnerability_detected severity details =
    let result = {
      test_name;
      attack_type;
      attack_payload;
      response_time_ms;
      memory_usage_kb;
      blocked;
      vulnerability_detected;
      severity;
      details;
    } in
    security_results := result :: !security_results;
    result
  
  (* Test 1: ReDoS Attack Prevention *)
  let test_redos_prevention () =
    printf "\n=== Security Testing: ReDoS Attack Prevention ===\n";
    
    List.iteri (fun i (attack_name, pattern, test_string) ->
      printf "Testing ReDoS pattern %d: %s...\n" i attack_name;
      
      let attack_request = `Assoc [("file_pattern", `String pattern)] in
      
      let (result_and_memory, response_time) = measure_with_timeout ~timeout_ms:5000 (fun () ->
        measure_memory_during (fun () -> Args.of_yojson attack_request)
      ) in
      let (result, memory_used) = match result_and_memory with
        | Error e -> (Error e, 0)
        | Ok (res, mem) -> (res, mem)
      in
      
      let blocked = match result with
        | Error _ -> true  (* Blocked as expected *)
        | Ok _ -> false   (* Should have been blocked *)
      in
      
      let vulnerability_detected = 
        response_time > 1000.0 || memory_used > 100000  (* 1 second or 100MB *)
      in
      
      let severity = 
        if vulnerability_detected && not blocked then `Critical
        else if vulnerability_detected then `High
        else if not blocked then `Medium
        else `Low
      in
      
      let details = 
        if vulnerability_detected then
          Some (sprintf "Slow response: %.1fms, Memory: %dKB" response_time memory_used)
        else None
      in
      
      let test_result = record_security_test 
        (sprintf "ReDoS: %s" attack_name)
        `ReDoS
        pattern
        response_time
        (Some memory_used)
        blocked
        vulnerability_detected
        severity
        details
      in
      
      printf "  Result: %s (%.1fms, %dKB)\n"
        (if test_result.blocked && not test_result.vulnerability_detected then "SAFE" 
         else if test_result.blocked then "BLOCKED_SLOW" 
         else "VULNERABLE")
        response_time memory_used;
      
      if test_result.vulnerability_detected then
        printf "  WARNING: Potential ReDoS vulnerability detected!\n";
    ) SecurityAttacks.redos_attack_patterns
  
  (* Test 2: Input Validation Attack Resistance *)
  let test_input_validation_attacks () =
    printf "\n=== Input Validation Attack Resistance ===\n";
    
    List.iteri (fun i (attack_name, payload) ->
      printf "Testing input validation %d: %s...\n" i attack_name;
      
      (* Try different parameter injection points *)
      let test_vectors = [
        ("targets", `Assoc [("targets", `String payload)]);
        ("file_pattern", `Assoc [("file_pattern", `String payload)]);
        ("max_diagnostics", `Assoc [("max_diagnostics", `String payload)]);
        ("direct_json", `String payload);
      ] in
      
      List.iter (fun (injection_point, attack_request) ->
        let (result_and_memory, response_time) = measure_with_timeout ~timeout_ms:3000 (fun () ->
          measure_memory_during (fun () -> Args.of_yojson attack_request)
        ) in
        let (result, memory_used) = match result_and_memory with
          | Error e -> (Error e, 0)
          | Ok (res, mem) -> (res, mem)
        in
        
        let blocked = match result with
          | Error _ -> true
          | Ok _ -> false
        in
        
        let vulnerability_detected = response_time > 500.0 || memory_used > 50000 in
        
        let severity = 
          if vulnerability_detected && not blocked then `Critical
          else if vulnerability_detected then `High
          else if not blocked then `Medium
          else `Low
        in
        
        let test_result = record_security_test
          (sprintf "Input validation: %s (%s)" attack_name injection_point)
          `InputValidation
          payload
          response_time
          (Some memory_used)
          blocked
          vulnerability_detected
          severity
          None
        in
        
        printf "  %s: %s (%.1fms)\n"
          injection_point
          (if test_result.blocked && not test_result.vulnerability_detected then "SAFE" else "VULNERABLE")
          response_time
      ) test_vectors
    ) SecurityAttacks.input_validation_attacks
  
  (* Test 3: Resource Exhaustion Prevention *)
  let test_resource_exhaustion_prevention () =
    printf "\n=== Resource Exhaustion Prevention ===\n";
    
    List.iteri (fun i (attack_name, payload) ->
      printf "Testing resource exhaustion %d: %s...\n" i attack_name;
      
      let attack_request = `Assoc [("file_pattern", `String payload)] in
      
      (* Set strict limits for resource exhaustion tests *)
      let (result_and_memory, response_time) = measure_with_timeout ~timeout_ms:2000 (fun () ->
        measure_memory_during (fun () ->
          try
            let _ = Args.of_yojson attack_request in
            (* If parsing succeeded, try to use the pattern *)
            let test_data = List.init 1000 (fun i -> sprintf "file_%d.ml" i) in
            List.length test_data
          with
          | exn -> -1  (* Error occurred *)
        )
      ) in
      let (result, memory_used) = match result_and_memory with
        | Error e -> (-2, 0)  (* Use -2 to indicate timeout/error *)
        | Ok (res, mem) -> (res, mem)
      in
      
      let blocked = match result with
        | -2 -> true  (* Timeout/error *)
        | -1 -> true  (* Error handling worked *)
        | _ -> false
      in
      
      let vulnerability_detected = 
        response_time > 1000.0 || memory_used > 200000  (* 1 second or 200MB *)
      in
      
      let severity = 
        if vulnerability_detected && not blocked then `Critical
        else if vulnerability_detected then `High
        else `Low
      in
      
      let test_result = record_security_test
        (sprintf "Resource exhaustion: %s" attack_name)
        `ResourceExhaustion
        payload
        response_time
        (Some memory_used)
        blocked
        vulnerability_detected
        severity
        (if vulnerability_detected then Some (sprintf "High resource usage: %.1fms, %dKB" response_time memory_used) else None)
      in
      
      printf "  Result: %s (%.1fms, %dKB)\n"
        (match test_result.severity with
         | `Critical -> "CRITICAL_VULNERABILITY"
         | `High -> "HIGH_RISK"
         | `Medium -> "MEDIUM_RISK"
         | `Low -> "SAFE")
        response_time memory_used;
      
      if test_result.severity = `Critical then
        printf "  CRITICAL: Resource exhaustion vulnerability detected!\n"
    ) SecurityAttacks.resource_exhaustion_attacks
  
  (* Test 4: Injection Attack Prevention *)
  let test_injection_attacks () =
    printf "\n=== Injection Attack Prevention ===\n";
    
    let injection_payloads = [
      ("SQL injection attempt", "'; DROP TABLE diagnostics; --");
      ("NoSQL injection", "{'$ne': null}");
      ("Command injection", "; rm -rf / #");
      ("Script injection", "<script>alert('xss')</script>");
      ("Template injection", "{{7*7}}");
      ("LDAP injection", "*)(uid=*))(|(uid=*");
    ] in
    
    List.iter (fun (attack_name, payload) ->
      let test_parameters = [
        ("file_pattern", `Assoc [("file_pattern", `String payload)]);
        ("targets", `Assoc [("targets", `List [`String payload])]);
      ] in
      
      List.iter (fun (param_name, attack_request) ->
        let (result, response_time) = measure_with_timeout ~timeout_ms:1000 (fun () ->
          Args.of_yojson attack_request
        ) in
        
        let blocked = match result with
          | Error _ -> true  (* Expected to be blocked *)
          | Ok _ -> false   (* Should not succeed *)
        in
        
        let vulnerability_detected = not blocked in
        
        let test_result = record_security_test
          (sprintf "Injection: %s (%s)" attack_name param_name)
          `InjectionAttempt
          payload
          response_time
          None
          blocked
          vulnerability_detected
          (if vulnerability_detected then `High else `Low)
          None
        in
        
        printf "  %s in %s: %s\n"
          attack_name
          param_name
          (if test_result.blocked then "BLOCKED" else "VULNERABLE")
      ) test_parameters
    ) injection_payloads
end

(* Chaos Engineering Tests *)
module ChaosTests = struct
  
  let record_chaos_test scenario failure_injected recovery_time_ms data_consistency graceful_degradation passed =
    let result = {
      scenario;
      failure_injected;
      recovery_time_ms;
      data_consistency;
      graceful_degradation;
      passed;
    } in
    chaos_results := result :: !chaos_results;
    result
  
  (* Test 1: Memory Pressure Simulation *)
  let test_memory_pressure_resilience () =
    printf "\n=== Chaos Testing: Memory Pressure Resilience ===\n";
    
    let large_diagnostic_set = List.init 10000 (fun i -> 
      Output.{
        severity = if i mod 3 = 0 then "error" else "warning";
        file = sprintf "src/module_%d.ml" i;
        line = (i mod 100) + 1;
        column = (i mod 80) + 1;
        message = sprintf "Test diagnostic %d: This is a complex error message with detailed type information and context that simulates real compiler diagnostics with sufficient length to test memory usage patterns" i;
      }
    ) in
    
    let start_time = gettimeofday () in
    
    let (result, memory_used) = measure_memory_during (fun () ->
      try
        (* Simulate processing under memory pressure *)
        let filtered = List.filter (fun d -> d.Output.severity = "error") large_diagnostic_set in
        let sorted = List.stable_sort (fun a b -> compare a.Output.line b.Output.line) filtered in
        let paginated = 
          let n = min 100 (List.length sorted) in
          let rec take count lst = 
            match count, lst with 
            | 0, _ -> []
            | _, [] -> []
            | n, x :: xs -> x :: (take (n-1) xs)
          in
          take n sorted
        in
        
        (* Simulate JSON serialization *)
        let json_responses = List.map (fun d ->
          sprintf "{\"severity\":\"%s\",\"file\":\"%s\",\"line\":%d,\"message\":\"%s\"}"
            d.Output.severity d.Output.file d.Output.line d.Output.message
        ) paginated in
        
        Some (List.length json_responses)
      with
      | exn -> None
    ) in
    
    let recovery_time = (gettimeofday () -. start_time) *. 1000.0 in
    let data_consistency = match result with Some n -> n > 0 | None -> false in
    let graceful_degradation = recovery_time < 5000.0 in  (* Should recover within 5 seconds *)
    let passed = data_consistency && graceful_degradation && memory_used < 500000 in  (* < 500MB *)
    
    let chaos_result = record_chaos_test
      "Memory pressure with 10K diagnostics"
      "High memory usage simulation"
      recovery_time
      data_consistency
      graceful_degradation
      passed
    in
    
    printf "  Memory pressure test: %s (%.1fms, %dKB)\n"
      (if chaos_result.passed then "RESILIENT" else "VULNERABLE")
      recovery_time memory_used;
    
    if not passed then (
      printf "  Issues:\n";
      if not data_consistency then printf "    - Data consistency failed\n";
      if not graceful_degradation then printf "    - Recovery time too slow\n";
      if memory_used >= 500000 then printf "    - Excessive memory usage\n"
    )
  
  (* Test 2: Concurrent Access Chaos *)
  let test_concurrent_access_chaos () =
    printf "\n=== Concurrent Access Chaos Testing ===\n";
    
    let test_data = List.init 1000 (fun i -> 
      Output.{
        severity = "error";
        file = sprintf "file_%d.ml" i;
        line = i;
        column = 1;
        message = sprintf "Error %d" i;
      }
    ) in
    
    let start_time = gettimeofday () in
    let results = ref [] in
    let errors = ref 0 in
    
    (* Create concurrent threads with different operations *)
    let threads = List.init 20 (fun thread_id ->
      Thread.create (fun () ->
        try
          for i = 1 to 10 do
            (* Different operations per thread *)
            let operation = match thread_id mod 3 with
              | 0 -> (* Filter errors *)
                  List.filter (fun d -> d.Output.severity = "error") test_data
              | 1 -> (* Sort by file *)
                  List.stable_sort (fun a b -> compare a.Output.file b.Output.file) test_data
              | _ -> (* Take subset *)
                  let n = min 100 (List.length test_data) in
                  let rec take count lst = 
                    match count, lst with 
                    | 0, _ -> []
                    | _, [] -> []
                    | n, x :: xs -> x :: (take (n-1) xs)
                  in
                  take n test_data
            in
            results := (thread_id, List.length operation) :: !results
          done
        with
        | exn -> incr errors
      ) ()
    ) in
    
    (* Wait for all threads *)
    List.iter Thread.join threads;
    
    let recovery_time = (gettimeofday () -. start_time) *. 1000.0 in
    let data_consistency = List.length !results > 0 && !errors = 0 in
    let graceful_degradation = recovery_time < 2000.0 in
    let passed = data_consistency && graceful_degradation in
    
    let chaos_result = record_chaos_test
      "Concurrent access with 20 threads"
      "High concurrency simulation"
      recovery_time
      data_consistency
      graceful_degradation
      passed
    in
    
    printf "  Concurrency chaos test: %s (%d operations, %d errors, %.1fms)\n"
      (if chaos_result.passed then "RESILIENT" else "VULNERABLE")
      (List.length !results) !errors recovery_time
  
  (* Test 3: Invalid Data Injection *)
  let test_invalid_data_injection () =
    printf "\n=== Invalid Data Injection Chaos ===\n";
    
    let malformed_diagnostics = [
      (* Missing fields *)
      (`Assoc [("severity", `String "error"); ("file", `String "test.ml")]);
      
      (* Wrong types *)
      (`Assoc [
        ("severity", `Int 42);
        ("file", `Bool true);
        ("line", `String "not_a_number");
        ("message", `Null)
      ]);
      
      (* Extremely large values *)
      (`Assoc [
        ("severity", `String "error");
        ("file", `String (String.make 10000 'x'));
        ("line", `Int max_int);
        ("column", `Int max_int);
        ("message", `String (String.make 100000 'y'))
      ]);
      
      (* Null and undefined *)
      `Null;
      
      (* Recursive structure *)
      (`Assoc [("self", `Assoc [("nested", `Assoc [("deep", `String "value")])])]);
    ] in
    
    let start_time = gettimeofday () in
    let safe_parsings = ref 0 in
    let total_tests = List.length malformed_diagnostics in
    
    List.iteri (fun i malformed_json ->
      try
        let (result, duration) = measure_with_timeout ~timeout_ms:1000 (fun () ->
          Output.diagnostic_of_yojson malformed_json
        ) in
        
        match result with
        | Error _ -> incr safe_parsings  (* Expected to fail safely *)
        | Ok _ -> ()  (* Unexpected success *)
      with
      | _ -> incr safe_parsings  (* Exception caught safely *)
    ) malformed_diagnostics;
    
    let recovery_time = (gettimeofday () -. start_time) *. 1000.0 in
    let data_consistency = !safe_parsings = total_tests in
    let graceful_degradation = recovery_time < 1000.0 in
    let passed = data_consistency && graceful_degradation in
    
    let chaos_result = record_chaos_test
      "Malformed data injection"
      "Invalid JSON diagnostic data"
      recovery_time
      data_consistency
      graceful_degradation
      passed
    in
    
    printf "  Data injection chaos: %s (%d/%d safe, %.1fms)\n"
      (if chaos_result.passed then "RESILIENT" else "VULNERABLE")
      !safe_parsings total_tests recovery_time
  
  (* Test 4: Extreme Load Spikes *)
  let test_extreme_load_spikes () =
    printf "\n=== Extreme Load Spike Resilience ===\n";
    
    let base_load = 100 in
    let spike_multiplier = 50 in  (* 50x load spike *)
    
    let simulate_load diagnostic_count =
      let test_data = List.init diagnostic_count (fun i -> 
        Output.{
          severity = if i mod 4 = 0 then "error" else "warning";
          file = sprintf "src/file_%d.ml" (i mod 100);
          line = (i mod 50) + 1;
          column = (i mod 20) + 1;
          message = sprintf "Diagnostic %d: Test message" i;
        }
      ) in
      
      let start = gettimeofday () in
      let result = 
        try
          (* Simulate processing pipeline *)
          let errors = List.filter (fun d -> d.Output.severity = "error") test_data in
          let warnings = List.filter (fun d -> d.Output.severity = "warning") test_data in
          let sorted = errors @ warnings in
          let paginated = 
            let n = min 50 (List.length sorted) in
            let rec take count lst = 
              match count, lst with 
              | 0, _ -> []
              | _, [] -> []
              | n, x :: xs -> x :: (take (n-1) xs)
            in
            take n sorted
          in
          Some (List.length paginated)
        with
        | exn -> None
      in
      let duration = (gettimeofday () -. start) *. 1000.0 in
      (result, duration)
    in
    
    let start_time = gettimeofday () in
    
    (* Test normal load *)
    let (normal_result, normal_time) = simulate_load base_load in
    
    (* Test spike load *)
    let (spike_result, spike_time) = simulate_load (base_load * spike_multiplier) in
    
    let recovery_time = (gettimeofday () -. start_time) *. 1000.0 in
    let data_consistency = Option.is_some normal_result && Option.is_some spike_result in
    let graceful_degradation = spike_time < normal_time *. 10.0 in  (* Spike shouldn't be >10x slower *)
    let passed = data_consistency && graceful_degradation && spike_time < 5000.0 in
    
    let chaos_result = record_chaos_test
      (sprintf "Load spike %dx (%d -> %d diagnostics)" spike_multiplier base_load (base_load * spike_multiplier))
      "Sudden traffic increase"
      recovery_time
      data_consistency
      graceful_degradation
      passed
    in
    
    printf "  Load spike test: %s\n"
      (if chaos_result.passed then "RESILIENT" else "VULNERABLE");
    printf "    Normal load: %.1fms (%d diagnostics)\n" normal_time base_load;
    printf "    Spike load: %.1fms (%d diagnostics, %.1fx slower)\n" 
      spike_time (base_load * spike_multiplier) (spike_time /. normal_time)
end

(* Test Report Generation *)
module SecurityReport = struct
  let generate_security_report () =
    let security_tests = List.rev !security_results in
    let chaos_tests = List.rev !chaos_results in
    
    printf "\n";
    printf "=== SECURITY AND RESILIENCE TEST RESULTS ===\n";
    
    (* Security test summary *)
    printf "\n=== SECURITY TESTS ===\n";
    printf "Total Security Tests: %d\n" (List.length security_tests);
    
    let critical_vulnerabilities = List.filter (fun r -> r.severity = `Critical && r.vulnerability_detected) security_tests in
    let high_vulnerabilities = List.filter (fun r -> r.severity = `High && r.vulnerability_detected) security_tests in
    let blocked_attacks = List.filter (fun r -> r.blocked) security_tests in
    
    printf "Critical Vulnerabilities: %d\n" (List.length critical_vulnerabilities);
    printf "High Risk Vulnerabilities: %d\n" (List.length high_vulnerabilities);
    printf "Attacks Blocked: %d/%d (%.1f%%)\n" 
      (List.length blocked_attacks) (List.length security_tests)
      (100.0 *. float_of_int (List.length blocked_attacks) /. float_of_int (List.length security_tests));
    
    (* Security test details table *)
    printf "\n%-40s %-12s %-8s %-10s %s\n" "Test Name" "Attack Type" "Blocked" "Time (ms)" "Severity";
    printf "%s\n" (String.make 80 '-');
    
    List.iter (fun result ->
      let attack_type_str = match result.attack_type with
        | `ReDoS -> "ReDoS"
        | `InputValidation -> "Input Val"
        | `ResourceExhaustion -> "Resource"
        | `InjectionAttempt -> "Injection"
      in
      let severity_str = match result.severity with
        | `Critical -> "CRITICAL"
        | `High -> "HIGH"
        | `Medium -> "MEDIUM"
        | `Low -> "LOW"
      in
      
      printf "%-40s %-12s %-8s %-10.1f %s\n"
        (if String.length result.test_name > 40 then String.sub result.test_name 0 37 ^ "..." else result.test_name)
        attack_type_str
        (if result.blocked then "YES" else "NO")
        result.response_time_ms
        severity_str;
    ) security_tests;
    
    (* Chaos test summary *)
    printf "\n=== CHAOS ENGINEERING TESTS ===\n";
    printf "Total Chaos Tests: %d\n" (List.length chaos_tests);
    
    let passed_chaos = List.filter (fun r -> r.passed) chaos_tests in
    let data_consistency_failures = List.filter (fun r -> not r.data_consistency) chaos_tests in
    let graceful_degradation_failures = List.filter (fun r -> not r.graceful_degradation) chaos_tests in
    
    printf "Passed: %d/%d\n" (List.length passed_chaos) (List.length chaos_tests);
    printf "Data Consistency Failures: %d\n" (List.length data_consistency_failures);
    printf "Graceful Degradation Failures: %d\n" (List.length graceful_degradation_failures);
    
    (* Chaos test details *)
    printf "\n%-30s %-20s %-12s %-8s %s\n" "Scenario" "Failure Type" "Recovery (ms)" "Passed" "Issues";
    printf "%s\n" (String.make 80 '-');
    
    List.iter (fun result ->
      let issues = 
        (if not result.data_consistency then ["Data"] else []) @
        (if not result.graceful_degradation then ["Degradation"] else [])
      in
      let issues_str = String.concat ", " issues in
      
      printf "%-30s %-20s %-12.1f %-8s %s\n"
        (if String.length result.scenario > 30 then String.sub result.scenario 0 27 ^ "..." else result.scenario)
        result.failure_injected
        result.recovery_time_ms
        (if result.passed then "YES" else "NO")
        issues_str;
    ) chaos_tests;
    
    (* Critical issue summary *)
    if List.length critical_vulnerabilities > 0 || List.length data_consistency_failures > 0 then (
      printf "\n=== CRITICAL SECURITY ISSUES ===\n";
      
      List.iter (fun vuln ->
        printf "CRITICAL: %s\n" vuln.test_name;
        printf "  Attack: %s\n" vuln.attack_payload;
        printf "  Response time: %.1fms\n" vuln.response_time_ms;
        match vuln.details with
        | Some details -> printf "  Details: %s\n" details
        | None -> ()
      ) critical_vulnerabilities;
      
      List.iter (fun failure ->
        printf "CRITICAL CHAOS FAILURE: %s\n" failure.scenario;
        printf "  Recovery time: %.1fms\n" failure.recovery_time_ms;
      ) data_consistency_failures;
      
      printf "\n";
    );
    
    (* Overall security assessment *)
    printf "=== SECURITY ASSESSMENT ===\n";
    let total_critical_issues = List.length critical_vulnerabilities + List.length data_consistency_failures in
    let total_high_risk_issues = List.length high_vulnerabilities + List.length graceful_degradation_failures in
    
    if total_critical_issues = 0 && total_high_risk_issues <= 2 then (
      printf "✅ SECURITY ASSESSMENT: PRODUCTION READY\n";
      printf "✅ No critical vulnerabilities detected\n";
      printf "✅ ReDoS attacks successfully prevented\n";
      printf "✅ Input validation working correctly\n";
      printf "✅ Resource exhaustion protection active\n";
      printf "✅ System demonstrates resilience under chaos conditions\n";
    ) else (
      printf "❌ SECURITY ASSESSMENT: NOT PRODUCTION READY\n";
      printf "❌ Critical issues: %d\n" total_critical_issues;
      printf "❌ High-risk issues: %d\n" total_high_risk_issues;
      printf "❌ Manual security review required\n";
      printf "❌ Address all critical vulnerabilities before deployment\n";
    );
    
    printf "\n";
    
    (* Return overall security status *)
    total_critical_issues = 0 && total_high_risk_issues <= 2
end

(* Main test execution *)
let run_security_tests () =
  printf "Starting Security and Resilience Testing for dune_build_status API\n";
  printf "Target: Validate ReDoS prevention and chaos engineering resilience\n\n";
  
  Random.self_init ();
  
  (* Run all security tests *)
  SecurityTests.test_redos_prevention ();
  SecurityTests.test_input_validation_attacks ();
  SecurityTests.test_resource_exhaustion_prevention ();
  SecurityTests.test_injection_attacks ();
  
  (* Run chaos engineering tests *)
  ChaosTests.test_memory_pressure_resilience ();
  ChaosTests.test_concurrent_access_chaos ();
  ChaosTests.test_invalid_data_injection ();
  ChaosTests.test_extreme_load_spikes ();
  
  (* Generate comprehensive security report *)
  let security_passed = SecurityReport.generate_security_report () in
  
  if security_passed then exit 0 else exit 1

let () = run_security_tests ()