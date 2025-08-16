(* Comprehensive API Testing Suite Runner *)
(* Orchestrates all API contract tests for dune_build_status MCP tool *)

open Printf

type test_suite = {
  name: string;
  executable: string;
  description: string;
  critical: bool; (* If true, failure of this suite fails the entire test run *)
  timeout_seconds: int;
}

type test_result = {
  suite_name: string;
  passed: bool;
  execution_time_ms: float;
  output: string;
  error_output: string;
}

(* Test suite configuration *)
let test_suites = [
  {
    name = "Contract Validation";
    executable = "./test_contract_validation";
    description = "Validates API contract compliance against exact schema requirements";
    critical = true;
    timeout_seconds = 30;
  };
  {
    name = "Comprehensive API Tests";
    executable = "./test_api_contract_comprehensive";
    description = "Complete API behavior testing including performance and edge cases";
    critical = true;
    timeout_seconds = 60;
  };
  {
    name = "Load Testing";
    executable = "./test_load_testing";
    description = "Realistic load testing with virtual users and traffic patterns";
    critical = true;
    timeout_seconds = 300; (* 5 minutes for load testing *)
  };
  {
    name = "Security & Chaos";
    executable = "./test_security_chaos";
    description = "Security vulnerability and chaos engineering testing";
    critical = true;
    timeout_seconds = 120;
  };
  {
    name = "JSON Contract";
    executable = "./test_build_status_json_contract";
    description = "Legacy JSON contract testing for backward compatibility";
    critical = false;
    timeout_seconds = 30;
  };
  {
    name = "Schema Validation";
    executable = "./test_build_status_schemas";
    description = "Legacy schema validation testing";
    critical = false;
    timeout_seconds = 30;
  };
]

(* Test execution with timeout *)
let run_test_with_timeout suite =
  let start_time = Unix.gettimeofday () in
  
  printf "Running %s...\n" suite.name;
  printf "  Description: %s\n" suite.description;
  printf "  Executable: %s\n" suite.executable;
  printf "  Timeout: %d seconds\n" suite.timeout_seconds;
  
  (* Create pipes for capturing output *)
  let (stdout_read, stdout_write) = Unix.pipe () in
  let (stderr_read, stderr_write) = Unix.pipe () in
  
  let process_result = try
    (* Start the test process *)
    let pid = Unix.create_process suite.executable [|suite.executable|] Unix.stdin stdout_write stderr_write in
    
    (* Close write ends in parent *)
    Unix.close stdout_write;
    Unix.close stderr_write;
    
    (* Wait for process with timeout *)
    let rec wait_with_timeout remaining_time =
      if remaining_time <= 0.0 then begin
        (* Timeout - kill the process *)
        (try Unix.kill pid Sys.sigterm with _ -> ());
        Unix.sleepf 1.0; (* Give it a chance to terminate gracefully *)
        (try Unix.kill pid Sys.sigkill with _ -> ());
        `Timeout
      end else begin
        match Unix.waitpid [Unix.WNOHANG] pid with
        | (0, _) -> 
            (* Process still running *)
            Unix.sleepf 0.1;
            wait_with_timeout (remaining_time -. 0.1)
        | (child_pid, status) when child_pid = pid ->
            (* Process completed *)
            `Completed status
        | _ -> 
            (* Unexpected result *)
            `Error "Unexpected waitpid result"
      end
    in
    
    wait_with_timeout (float_of_int suite.timeout_seconds)
  with
  | Unix.Unix_error (Unix.ENOENT, _, _) ->
      `Not_Found
  | exn ->
      `Exception (Printexc.to_string exn)
  in
  
  (* Read output *)
  let read_all_from_fd fd =
    let buffer = Buffer.create 4096 in
    let temp_buffer = Bytes.create 1024 in
    let rec read_loop () =
      try
        let bytes_read = Unix.read fd temp_buffer 0 1024 in
        if bytes_read > 0 then begin
          Buffer.add_subbytes buffer temp_buffer 0 bytes_read;
          read_loop ()
        end else
          Buffer.contents buffer
      with
      | Unix.Unix_error (Unix.EAGAIN, _, _) -> Buffer.contents buffer
      | Unix.Unix_error (Unix.EBADF, _, _) -> Buffer.contents buffer
      | _ -> Buffer.contents buffer
    in
    read_loop ()
  in
  
  let stdout_content = read_all_from_fd stdout_read in
  let stderr_content = read_all_from_fd stderr_read in
  
  Unix.close stdout_read;
  Unix.close stderr_read;
  
  let execution_time = (Unix.gettimeofday () -. start_time) *. 1000.0 in
  
  let passed = match process_result with
    | `Completed (Unix.WEXITED 0) -> true
    | _ -> false
  in
  
  let result = {
    suite_name = suite.name;
    passed;
    execution_time_ms = execution_time;
    output = stdout_content;
    error_output = stderr_content;
  } in
  
  (* Print result summary *)
  let status = if passed then "✅ PASS" else "❌ FAIL" in
  printf "  Result: %s (%.2fms)\n" status execution_time;
  
  if not passed then begin
    printf "  Process result: %s\n" (match process_result with
      | `Completed (Unix.WEXITED code) -> sprintf "Exit code: %d" code
      | `Completed (Unix.WSIGNALED signal) -> sprintf "Killed by signal: %d" signal
      | `Completed (Unix.WSTOPPED signal) -> sprintf "Stopped by signal: %d" signal
      | `Timeout -> "Timeout"
      | `Not_Found -> "Executable not found"
      | `Exception msg -> sprintf "Exception: %s" msg
      | `Error msg -> sprintf "Error: %s" msg
    );
    
    if String.length stderr_content > 0 then begin
      printf "  Error output:\n";
      let lines = String.split_on_char '\n' stderr_content in
      List.iter (fun line -> if String.length line > 0 then printf "    %s\n" line) lines
    end
  end;
  
  printf "\n";
  result

(* Main test runner *)
let run_comprehensive_test_suite () =
  printf "=== COMPREHENSIVE API CONTRACT TESTING SUITE ===\n";
  printf "Testing dune_build_status MCP tool for production readiness\n";
  printf "Issue #2 Resolution: Token limit enforcement and performance optimization\n";
  printf "\n";
  
  printf "Test Suite Configuration:\n";
  List.iter (fun suite -> 
    let criticality = if suite.critical then "CRITICAL" else "optional" in
    printf "- %s (%s): %s\n" suite.name criticality suite.description
  ) test_suites;
  printf "\n";
  
  let start_time = Unix.gettimeofday () in
  
  (* Run all test suites *)
  let results = List.map run_test_with_timeout test_suites in
  
  let total_time = (Unix.gettimeofday () -. start_time) *. 1000.0 in
  
  (* Analyze results *)
  let total_suites = List.length results in
  let passed_results = List.filter (fun r -> r.passed) results in
  let failed_results = List.filter (fun r -> not r.passed) results in
  let passed_count = List.length passed_results in
  let failed_count = List.length failed_results in
  
  let critical_results = List.filter (fun r -> 
    let suite = List.find (fun s -> s.name = r.suite_name) test_suites in
    suite.critical
  ) results in
  let critical_passed = List.filter (fun r -> r.passed) critical_results in
  let critical_failed = List.filter (fun r -> not r.passed) critical_results in
  
  printf "=== COMPREHENSIVE TEST RESULTS ===\n";
  printf "Execution time: %.2f seconds\n" (total_time /. 1000.0);
  printf "Total test suites: %d\n" total_suites;
  printf "Passed: %d\n" passed_count;
  printf "Failed: %d\n" failed_count;
  printf "Success rate: %.1f%%\n" (100.0 *. float_of_int passed_count /. float_of_int total_suites);
  printf "\n";
  
  printf "Critical test suites: %d\n" (List.length critical_results);
  printf "Critical passed: %d\n" (List.length critical_passed);
  printf "Critical failed: %d\n" (List.length critical_failed);
  
  if List.length critical_failed > 0 then
    printf "Critical success rate: %.1f%%\n" 
           (100.0 *. float_of_int (List.length critical_passed) /. float_of_int (List.length critical_results))
  else
    printf "Critical success rate: 100.0%%\n";
  
  printf "\n=== DETAILED RESULTS ===\n";
  List.iter (fun result ->
    let status = if result.passed then "✅" else "❌" in
    let suite = List.find (fun s -> s.name = result.suite_name) test_suites in
    let criticality = if suite.critical then "[CRITICAL]" else "[optional]" in
    printf "%s %s %s - %.2fms\n" status result.suite_name criticality result.execution_time_ms
  ) results;
  
  if failed_count > 0 then begin
    printf "\n=== FAILED TEST DETAILS ===\n";
    List.iter (fun result ->
      let suite = List.find (fun s -> s.name = result.suite_name) test_suites in
      printf "\n❌ %s (Critical: %b)\n" result.suite_name suite.critical;
      
      (* Show key output snippets *)
      if String.length result.output > 0 then begin
        let lines = String.split_on_char '\n' result.output in
        let relevant_lines = List.filter (fun line -> 
          let lower_line = String.lowercase_ascii line in
          let contains_substring s sub = 
            let len_s = String.length s and len_sub = String.length sub in
            let rec check i = 
              if i > len_s - len_sub then false
              else if String.sub s i len_sub = sub then true
              else check (i + 1)
            in
            if len_sub = 0 then true else check 0
          in
          contains_substring lower_line "fail" || contains_substring lower_line "error"
        ) lines in
        if relevant_lines <> [] then begin
          printf "  Key output:\n";
          let rec take n lst = match n, lst with | 0, _ -> [] | _, [] -> [] | n, x :: xs -> x :: take (n-1) xs in
          List.iter (fun line -> printf "    %s\n" line) (take 5 relevant_lines)
        end
      end;
      
      if String.length result.error_output > 0 then begin
        printf "  Error output (first 500 chars):\n";
        let error_snippet = if String.length result.error_output > 500 then
          String.sub result.error_output 0 500 ^ "..."
        else result.error_output in
        let lines = String.split_on_char '\n' error_snippet in
        List.iter (fun line -> if String.length line > 0 then printf "    %s\n" line) lines
      end
    ) failed_results
  end;
  
  printf "\n=== PRODUCTION READINESS ASSESSMENT ===\n";
  
  let api_contract_passed = List.exists (fun r -> 
    r.suite_name = "Contract Validation" && r.passed
  ) results in
  
  let performance_passed = List.exists (fun r -> 
    r.suite_name = "Load Testing" && r.passed
  ) results in
  
  let security_passed = List.exists (fun r -> 
    r.suite_name = "Security & Chaos" && r.passed
  ) results in
  
  let comprehensive_passed = List.exists (fun r -> 
    r.suite_name = "Comprehensive API Tests" && r.passed
  ) results in
  
  printf "%s API Contract Compliance: Schema validation and parameter handling\n" 
         (if api_contract_passed then "✅" else "❌");
  printf "%s Performance Requirements: Load testing and response times\n" 
         (if performance_passed then "✅" else "❌");
  printf "%s Security & Resilience: Attack prevention and failure recovery\n" 
         (if security_passed then "✅" else "❌");
  printf "%s Comprehensive Coverage: Edge cases and functional testing\n" 
         (if comprehensive_passed then "✅" else "❌");
  
  printf "\n=== ISSUE #2 RESOLUTION STATUS ===\n";
  if List.length critical_failed = 0 then begin
    printf "✅ Token limit enforcement: 25k limit never exceeded\n";
    printf "✅ Performance optimization: Streaming implementation\n";
    printf "✅ Security hardening: ReDoS prevention active\n";
    printf "✅ API reliability: Contract compliance verified\n";
    printf "✅ Production readiness: All critical tests passed\n";
    
    printf "\n🎉 ALL CRITICAL TESTS PASSED! 🏆\n";
    printf "\nThe refactored dune_build_status MCP tool successfully resolves issue #2\n";
    printf "and provides a production-ready, battle-tested API that can handle:\n";
    printf "\n";
    printf "  • 100x viral traffic spikes without breaking\n";
    printf "  • Large diagnostic datasets (50k+) with constant memory\n";
    printf "  • Malicious input patterns and security attacks\n";
    printf "  • Network failures and cascading system issues\n";
    printf "  • Strict 25,000 token limits with no exceptions\n";
    printf "  • Sub-second response times under all conditions\n";
    printf "\n";
    printf "Ready for production deployment with confidence! 🚀\n";
    exit 0
  end else begin
    printf "❌ Critical test failures detected\n";
    printf "❌ Issue #2 resolution incomplete\n";
    printf "❌ Production readiness: BLOCKED\n";
    
    printf "\n💥 CRITICAL FAILURES DETECTED! 💥\n";
    printf "\nThe following critical issues must be resolved before production:\n";
    List.iter (fun result ->
      let suite = List.find (fun s -> s.name = result.suite_name) test_suites in
      if suite.critical then
        printf "  • %s: Critical functionality failure\n" result.suite_name
    ) failed_results;
    printf "\n";
    printf "Fix all critical issues and re-run the test suite.\n";
    printf "Production deployment is NOT RECOMMENDED until all tests pass.\n";
    exit 1
  end

(* Entry point *)
let () =
  (* Change to the test directory to find executables *)
  (try Unix.chdir (Sys.getcwd () ^ "/test/unit") with _ -> ());
  run_comprehensive_test_suite ()
