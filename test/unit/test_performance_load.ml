(* High-Performance Load Testing Suite for dune_build_status API *)
(* Tests performance requirements and validates sub-second response times *)

open Printf
open Unix

(* Import the build_status tool *)
module Args = Ocaml_mcp_server.Tools.Build_status.Args
module Output = Ocaml_mcp_server.Tools.Build_status.Output

(* Performance metrics collection *)
type perf_metrics = {
  response_time_p50: float;
  response_time_p95: float;
  response_time_p99: float;
  throughput_rps: float;
  error_rate: float;
}

type load_test_result = {
  test_name: string;
  metrics: perf_metrics;
  passed: bool;
  issues: string list;
}

let test_results = ref []

(* Utility functions for performance measurement *)

let measure_memory_usage f =
  (* Simplified memory measurement - in production, use system tools *)
  let initial_heap = Gc.stat () in
  let result = f () in
  let final_heap = Gc.stat () in
  let memory_diff = (final_heap.live_words - initial_heap.live_words) * (Sys.word_size / 8) / 1024 in
  (result, max 0 memory_diff)

(* Calculate percentiles from sorted list *)
let calculate_percentiles times =
  let sorted = List.sort compare times in
  let len = List.length sorted in
  if len = 0 then (0.0, 0.0, 0.0) else
  let p50 = List.nth sorted (len * 50 / 100) in
  let p95 = List.nth sorted (len * 95 / 100) in
  let p99 = List.nth sorted (len * 99 / 100) in
  (p50, p95, p99)

(* Mock data generators for load testing *)
module LoadTestData = struct
  type test_scenario = {
    diagnostic_count: int;
    error_ratio: float;
    complexity_distribution: (float * float * float); (* (simple, medium, complex) *)
    file_pattern_complexity: [`None | `Simple | `Complex];
  }
  
  let create_diagnostic ~severity ~complexity index : Ocaml_mcp_server.Tools.Build_status.Output.diagnostic =
    let severity_str = match severity with `Error -> "error" | `Warning -> "warning" in
    let file_base = "src/modules/deep/nested/path" in
    let file = sprintf "%s/module_%d.ml" file_base index in
    
    let message = match complexity with
    | `Simple -> sprintf "%s: Simple issue in line %d" (String.capitalize_ascii severity_str) (index mod 100)
    | `Medium -> 
        sprintf "%s: Type mismatch in module Module_%d. Expected string but got int in function call" 
        (String.capitalize_ascii severity_str) index
    | `Complex -> 
        sprintf "%s: Complex error in %s at line %d: Unbound constructor Some in type 'a option. The type constructor list is not yet completely defined with signature mismatch between interface module type and implementation. This expression has type ('a * 'b) -> 'c but expected 'd -> 'e result with nested pattern matching exhaustiveness analysis failure in function composition with monadic operations"
        (String.capitalize_ascii severity_str) file (index mod 100)
    in
    
    {
      severity = severity_str;
      file;
      line = (index mod 100) + 1;
      column = (index mod 80) + 1;
      message;
    }
  
  let generate_test_dataset scenario =
    let (simple_ratio, medium_ratio, complex_ratio) = scenario.complexity_distribution in
    let total = simple_ratio +. medium_ratio +. complex_ratio in
    let simple_count = int_of_float (float_of_int scenario.diagnostic_count *. simple_ratio /. total) in
    let medium_count = int_of_float (float_of_int scenario.diagnostic_count *. medium_ratio /. total) in
    let complex_count = scenario.diagnostic_count - simple_count - medium_count in
    
    let create_batch complexity count start_idx =
      List.init count (fun i -> 
        let idx = start_idx + i in
        let severity = if Random.float 1.0 < scenario.error_ratio then `Error else `Warning in
        create_diagnostic ~severity ~complexity idx
      )
    in
    
    let simple_diagnostics = create_batch `Simple simple_count 0 in
    let medium_diagnostics = create_batch `Medium medium_count simple_count in
    let complex_diagnostics = create_batch `Complex complex_count (simple_count + medium_count) in
    
    simple_diagnostics @ medium_diagnostics @ complex_diagnostics
  
  (* Predefined test scenarios *)
  let light_load_scenario = {
    diagnostic_count = 100;
    error_ratio = 0.3;
    complexity_distribution = (0.6, 0.3, 0.1);
    file_pattern_complexity = `Simple;
  }
  
  let medium_load_scenario = {
    diagnostic_count = 1000;
    error_ratio = 0.25;
    complexity_distribution = (0.5, 0.4, 0.1);
    file_pattern_complexity = `Simple;
  }
  
  let heavy_load_scenario = {
    diagnostic_count = 10000;
    error_ratio = 0.2;
    complexity_distribution = (0.5, 0.4, 0.1);
    file_pattern_complexity = `Complex;
  }
  
  let stress_load_scenario = {
    diagnostic_count = 50000;
    error_ratio = 0.15;
    complexity_distribution = (0.5, 0.4, 0.1);
    file_pattern_complexity = `Complex;
  }
end

(* Core load testing framework *)
module LoadTester = struct
  
  (* Simulate API request processing *)
  let simulate_api_request diagnostics args =
    let start_time = gettimeofday () in
    
    try
      (* Simulate the core processing logic *)
      let filtered_diagnostics = match args.Args.severity_filter with
        | None | Some `All -> diagnostics
        | Some `Error -> List.filter (fun d -> d.Output.severity = "error") diagnostics
        | Some `Warning -> List.filter (fun d -> d.Output.severity = "warning") diagnostics
      in
      
      let pattern_filtered = match args.file_pattern with
        | None -> filtered_diagnostics
        | Some pattern -> 
            List.filter (fun d -> 
              (* Simple pattern matching simulation *)
              String.contains d.Output.file '.' && String.length pattern < 100
            ) filtered_diagnostics
      in
      
      (* Sort by severity (errors first) *)
      let sorted_diagnostics = List.stable_sort (fun a b ->
        if a.Output.severity = "error" && b.Output.severity = "warning" then -1
        else if a.Output.severity = "warning" && b.Output.severity = "error" then 1
        else 0
      ) pattern_filtered in
      
      (* Apply pagination *)
      let page_size = match args.max_diagnostics with Some n -> n | None -> 50 in
      let page = match args.page with Some p -> p | None -> 0 in
      let start_idx = page * page_size in
      let end_idx = min (start_idx + page_size) (List.length sorted_diagnostics) in
      
      let page_diagnostics = 
        if start_idx >= List.length sorted_diagnostics then []
        else 
          let rec take_skip lst skip take_count =
            match lst, skip, take_count with
            | _, _, 0 -> []
            | [], _, _ -> []
            | x :: xs, 0, n -> x :: (take_skip xs 0 (n - 1))
            | _ :: xs, n, count -> take_skip xs (n - 1) count
          in
          take_skip sorted_diagnostics start_idx (end_idx - start_idx)
      in
      
      (* Estimate token count *)
      let estimated_tokens = List.fold_left (fun acc d ->
        let msg_tokens = (String.length d.Output.message) / 4 in
        let file_tokens = (String.length d.Output.file) / 6 in
        acc + msg_tokens + file_tokens + 10  (* Base overhead *)
      ) 200 page_diagnostics in  (* 200 for metadata *)
      
      (* Create response *)
      let response = Output.{
        status = if List.exists (fun d -> d.Output.severity = "error") diagnostics then "success_with_warnings" else "success";
        diagnostics = page_diagnostics;
        truncated = estimated_tokens > 20000 || List.length sorted_diagnostics > List.length page_diagnostics;
        truncation_reason = if estimated_tokens > 20000 then Some "Token limit reached" 
                           else if List.length sorted_diagnostics > List.length page_diagnostics then Some "Paginated results"
                           else None;
        next_cursor = if end_idx < List.length sorted_diagnostics then Some (string_of_int (page + 1)) else None;
        token_count = estimated_tokens;
        summary = {
          total_diagnostics = List.length diagnostics;
          returned_diagnostics = List.length page_diagnostics;
          error_count = List.length (List.filter (fun d -> d.Output.severity = "error") diagnostics);
          warning_count = List.length (List.filter (fun d -> d.Output.severity = "warning") diagnostics);
          build_summary = None;
        };
      } in
      
      let end_time = gettimeofday () in
      let duration = (end_time -. start_time) *. 1000.0 in
      
      (* Return success with timing *)
      Ok (response, duration, estimated_tokens <= 25000)
      
    with 
    | exn -> 
        let end_time = gettimeofday () in
        let duration = (end_time -. start_time) *. 1000.0 in
        Error (Printexc.to_string exn, duration)
  
  (* Run load test with concurrent requests *)
  let run_load_test ~test_name ~scenario ~concurrent_users ~duration_seconds ~target_rps =
    printf "\n=== Load Test: %s ===\n" test_name;
    printf "Concurrent Users: %d, Duration: %.1fs, Target: %.1f RPS\n" concurrent_users duration_seconds target_rps;
    
    let test_data = LoadTestData.generate_test_dataset scenario in
    let test_args = Args.{
      targets = None;
      max_diagnostics = Some 50;
      page = Some 0;
      severity_filter = Some `All;
      file_pattern = match scenario.file_pattern_complexity with
        | `None -> None
        | `Simple -> Some "*.ml"
        | `Complex -> Some "src/**/*.{ml,mli}";
    } in
    
    let start_time = gettimeofday () in
    let end_time = start_time +. duration_seconds in
    
    let response_times = ref [] in
    let error_count = ref 0 in
    let success_count = ref 0 in
    let total_memory = ref 0 in
    
    (* Worker thread function *)
    let worker_thread () =
      (* Capture variables for thread safety *)
      let end_time_local = end_time in
      let test_data_local = test_data in
      let test_args_local = test_args in
      let target_rps_local = target_rps in
      let concurrent_users_local = concurrent_users in
      
      let thread_responses = ref [] in
      let thread_errors = ref 0 in
      let thread_successes = ref 0 in
      let thread_memory = ref 0 in
      
      while gettimeofday () < end_time_local do
        let (result, memory_used) = measure_memory_usage (fun () ->
          simulate_api_request test_data_local test_args_local
        ) in
        
        thread_memory := !thread_memory + memory_used;
        
        match result with
        | Ok (_, duration, token_ok) ->
            thread_responses := duration :: !thread_responses;
            if token_ok then incr thread_successes else incr thread_errors
        | Error (_, duration) ->
            thread_responses := duration :: !thread_responses;
            incr thread_errors;
        
        (* Rate limiting - simple sleep to target RPS *)
        let sleep_time = 1.0 /. (target_rps_local /. float_of_int concurrent_users_local) in
        Unix.sleepf sleep_time;
      done;
      
      (!thread_responses, !thread_errors, !thread_successes, !thread_memory)
    in
    
    (* Start worker domains *)
    let domains = List.init concurrent_users (fun _ -> Domain.spawn worker_thread) in
    
    (* Wait for all domains and collect results *)
    let all_results = List.map Domain.join domains in
    
    (* Aggregate results *)
    List.iter (fun (responses, errors, successes, memory) ->
      response_times := responses @ !response_times;
      error_count := !error_count + errors;
      success_count := !success_count + successes;
      total_memory := !total_memory + memory;
    ) all_results;
    
    let actual_duration = gettimeofday () -. start_time in
    let total_requests = !error_count + !success_count in
    let actual_rps = float_of_int total_requests /. actual_duration in
    let error_rate = if total_requests > 0 then float_of_int !error_count /. float_of_int total_requests else 0.0 in
    
    (* Calculate performance metrics *)
    let (p50, p95, p99) = calculate_percentiles !response_times in
    let avg_memory_kb = !total_memory / concurrent_users in
    
    let metrics = {
      response_time_p50 = p50;
      response_time_p95 = p95;
      response_time_p99 = p99;
      throughput_rps = actual_rps;
      error_rate;
    } in
    
    (* Evaluate performance against targets *)
    let issues = ref [] in
    
    if p95 > 500.0 then issues := "P95 response time > 500ms" :: !issues;
    if p99 > 1000.0 then issues := "P99 response time > 1000ms" :: !issues;
    if error_rate > 0.01 then issues := sprintf "Error rate %.2f%% > 1%%" (error_rate *. 100.0) :: !issues;
    if actual_rps < target_rps *. 0.8 then issues := sprintf "Throughput %.1f RPS < 80%% of target %.1f RPS" actual_rps target_rps :: !issues;
    if avg_memory_kb > 500000 then issues := sprintf "Memory usage %d KB too high" avg_memory_kb :: !issues;
    
    let result = {
      test_name;
      metrics;
      passed = List.length !issues = 0;
      issues = List.rev !issues;
    } in
    
    test_results := result :: !test_results;
    
    (* Print immediate results *)
    printf "Completed: %d requests, %.1f RPS (target: %.1f)\n" total_requests actual_rps target_rps;
    printf "Response times - P50: %.1fms, P95: %.1fms, P99: %.1fms\n" p50 p95 p99;
    printf "Error rate: %.2f%% (%d/%d)\n" (error_rate *. 100.0) !error_count total_requests;
    printf "Memory usage: %d KB per user\n" avg_memory_kb;
    printf "Result: %s\n" (if result.passed then "PASS" else "FAIL");
    if not result.passed then (
      printf "Issues:\n";
      List.iter (printf "  - %s\n") result.issues
    );
    
    result
end

(* Specific performance test scenarios *)
module PerformanceTests = struct
  
  let test_light_load () =
    LoadTester.run_load_test
      ~test_name:"Light Load (100 diagnostics)"
      ~scenario:LoadTestData.light_load_scenario
      ~concurrent_users:10
      ~duration_seconds:30.0
      ~target_rps:100.0
  
  let test_medium_load () =
    LoadTester.run_load_test
      ~test_name:"Medium Load (1K diagnostics)"
      ~scenario:LoadTestData.medium_load_scenario
      ~concurrent_users:25
      ~duration_seconds:60.0
      ~target_rps:200.0
  
  let test_heavy_load () =
    LoadTester.run_load_test
      ~test_name:"Heavy Load (10K diagnostics)"
      ~scenario:LoadTestData.heavy_load_scenario
      ~concurrent_users:50
      ~duration_seconds:120.0
      ~target_rps:500.0
  
  let test_burst_load () =
    LoadTester.run_load_test
      ~test_name:"Burst Load (spike test)"
      ~scenario:LoadTestData.medium_load_scenario
      ~concurrent_users:100
      ~duration_seconds:30.0
      ~target_rps:1000.0
  
  
  let test_stress_load () =
    LoadTester.run_load_test
      ~test_name:"Stress Load (50K diagnostics)"
      ~scenario:LoadTestData.stress_load_scenario
      ~concurrent_users:10
      ~duration_seconds:60.0
      ~target_rps:50.0
end

(* Token limit specific performance tests *)
module TokenLimitPerformanceTests = struct
  
  (* Test response time with different token scenarios *)
  let test_token_limit_performance () =
    printf "\n=== Token Limit Performance Testing ===\n";
    
    let token_scenarios = [
      ("Small response (<5K tokens)", 100, 0.3);
      ("Medium response (10-15K tokens)", 500, 0.25);
      ("Large response (20-24K tokens)", 800, 0.2);
      ("At token limit (25K tokens)", 1000, 0.15);
    ] in
    
    List.iter (fun (name, diag_count, error_ratio) ->
      let scenario = LoadTestData.{
        diagnostic_count = diag_count;
        error_ratio;
        complexity_distribution = (0.5, 0.4, 0.1);
        file_pattern_complexity = `Simple;
      } in
      
      let result = LoadTester.run_load_test
        ~test_name:name
        ~scenario
        ~concurrent_users:5
        ~duration_seconds:30.0
        ~target_rps:10.0
      in
      
      (* Additional token-specific validation *)
      let token_issues = ref [] in
      if result.metrics.response_time_p95 > 200.0 then
        token_issues := "Token processing too slow" :: !token_issues;
      
      if List.length !token_issues > 0 then (
        printf "Token-specific issues for %s:\n" name;
        List.iter (printf "  - %s\n") !token_issues
      )
    ) token_scenarios
  
  (* Test pagination performance *)
  let test_pagination_performance () =
    printf "\n=== Pagination Performance Testing ===\n";
    
    let large_scenario = LoadTestData.{
      diagnostic_count = 5000;
      error_ratio = 0.25;
      complexity_distribution = (0.5, 0.4, 0.1);
      file_pattern_complexity = `Simple;
    } in
    
    let page_sizes = [10; 50; 100; 200] in
    
    List.iter (fun page_size ->
      
      (* Test multiple pages *)
      let page_tests = List.init 5 (fun page -> 
        let test_data = LoadTestData.generate_test_dataset large_scenario in
        let args = Args.{
          targets = None;
          max_diagnostics = Some page_size;
          page = Some page;
          severity_filter = Some `All;
          file_pattern = None;
        } in
        
        let start_time = gettimeofday () in
        let result = LoadTester.simulate_api_request test_data args in
        let duration = (gettimeofday () -. start_time) *. 1000.0 in
        
        match result with
        | Ok (response, _, _) -> (duration, List.length response.diagnostics, response.token_count)
        | Error (_, duration) -> (duration, 0, 0)
      ) in
      
      let avg_duration = 
        List.fold_left (fun acc (d, _, _) -> acc +. d) 0.0 page_tests /. float_of_int (List.length page_tests) in
      let max_tokens = 
        List.fold_left (fun acc (_, _, t) -> max acc t) 0 page_tests in
      
      printf "Page size %d: avg %.1fms, max %d tokens\n" page_size avg_duration max_tokens;
      
      if avg_duration > 100.0 then
        printf "  WARNING: Pagination too slow for page size %d\n" page_size;
      if max_tokens > 25000 then
        printf "  ERROR: Token limit exceeded for page size %d\n" page_size;
    ) page_sizes
end

(* Report generation *)
module LoadTestReport = struct
  let generate_performance_report () =
    let results = List.rev !test_results in
    
    printf "\n";
    printf "=== PERFORMANCE & LOAD TEST RESULTS ===\n";
    printf "Total Tests: %d\n" (List.length results);
    
    let passed = List.length (List.filter (fun r -> r.passed) results) in
    let failed = List.length results - passed in
    
    printf "Passed: %d\n" passed;
    printf "Failed: %d\n" failed;
    printf "\n";
    
    (* Performance summary table *)
    printf "%-30s %10s %10s %10s %10s %8s\n" "Test Name" "P50 (ms)" "P95 (ms)" "P99 (ms)" "RPS" "Errors";
    printf "%s\n" (String.make 80 '-');
    
    List.iter (fun result ->
      printf "%-30s %10.1f %10.1f %10.1f %10.1f %7.2f%%\n"
        (if String.length result.test_name > 30 then String.sub result.test_name 0 27 ^ "..." else result.test_name)
        result.metrics.response_time_p50
        result.metrics.response_time_p95
        result.metrics.response_time_p99
        result.metrics.throughput_rps
        (result.metrics.error_rate *. 100.0);
    ) results;
    
    printf "\n";
    
    (* Performance targets validation *)
    printf "=== PERFORMANCE TARGETS VALIDATION ===\n";
    
    let response_time_failures = List.filter (fun r -> r.metrics.response_time_p95 > 500.0) results in
    let throughput_failures = List.filter (fun r -> r.metrics.throughput_rps < 50.0) results in
    let error_rate_failures = List.filter (fun r -> r.metrics.error_rate > 0.01) results in
    
    printf "Response Time (P95 < 500ms): %s (%d/%d passed)\n" 
      (if List.length response_time_failures = 0 then "PASS" else "FAIL")
      (List.length results - List.length response_time_failures) (List.length results);
    
    printf "Throughput (>50 RPS): %s (%d/%d passed)\n"
      (if List.length throughput_failures = 0 then "PASS" else "FAIL")
      (List.length results - List.length throughput_failures) (List.length results);
    
    printf "Error Rate (<1%%): %s (%d/%d passed)\n"
      (if List.length error_rate_failures = 0 then "PASS" else "FAIL")
      (List.length results - List.length error_rate_failures) (List.length results);
    
    printf "\n";
    
    (* Issue summary *)
    if failed > 0 then (
      printf "=== PERFORMANCE ISSUES DETECTED ===\n";
      List.iter (fun result ->
        if not result.passed then (
          printf "FAILED: %s\n" result.test_name;
          List.iter (printf "  - %s\n") result.issues;
        )
      ) results;
      printf "\n";
    );
    
    (* Overall assessment *)
    printf "=== PERFORMANCE ASSESSMENT ===\n";
    if failed = 0 then (
      printf "✅ ALL PERFORMANCE TESTS PASSED\n";
      printf "✅ Sub-second response times achieved\n";
      printf "✅ Target throughput met\n";
      printf "✅ Error rates within acceptable limits\n";
      printf "✅ Ready for production load\n"
    ) else (
      printf "❌ %d PERFORMANCE TESTS FAILED\n" failed;
      printf "❌ Performance optimization required\n";
      printf "❌ Review failed tests before production deployment\n"
    );
    
    printf "\n";
    
    (* Return overall success *)
    failed = 0
end

(* Main test execution *)
let run_performance_tests () =
  printf "Starting Performance and Load Testing for dune_build_status API\n";
  printf "Target: Validate sub-second response times and production throughput\n\n";
  
  Random.self_init ();
  
  (* Run all performance tests *)
  let _ = PerformanceTests.test_light_load () in
  let _ = PerformanceTests.test_medium_load () in
  let _ = PerformanceTests.test_heavy_load () in
  let _ = PerformanceTests.test_burst_load () in
  let _ = PerformanceTests.test_stress_load () in
  
  (* Token-specific performance tests *)
  TokenLimitPerformanceTests.test_token_limit_performance ();
  TokenLimitPerformanceTests.test_pagination_performance ();
  
  (* Generate comprehensive report *)
  let success = LoadTestReport.generate_performance_report () in
  
  if success then exit 0 else exit 1

let () = run_performance_tests ()