Simple test for dune_build_status token limit parameters

This test verifies that the enhanced dune_build_status tool accepts
the new token limit parameters. This test will FAIL until the 
functionality is implemented.

=== Setup minimal project ===

  $ cat > dune-project << EOF
  > (lang dune 3.0)
  > (name simple_test)
  > EOF
  $ cat > dune << EOF
  > (executable (name main))
  > EOF
  $ cat > main.ml << EOF
  > let unused_var = "this generates a warning"
  > let () = print_endline "Hello"
  > EOF

=== Test that new parameters are accepted ===

  $ dune build --watch --root . &
  File "main.ml", line 1, characters 4-14:
  1 | let unused_var = "this generates a warning"
          ^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value unused_var.
  Had 1 error, waiting for filesystem changes...
  File "main.ml", line 1, characters 4-14:
  1 | let unused_var = "this generates a warning"
          ^^^^^^^^^^
  Error (warning 32 [unused-value-declaration]): unused value unused_var.
  Had 1 error, waiting for filesystem changes...
  $ DUNE_PID=$!
  $ ocaml-mcp-server --pipe test.sock &
  $ SERVER_PID=$!
  $ sleep 1

The following calls should now work with the enhanced API:

  $ mcp --pipe test.sock call dune_build_status '{"max_tokens": 1000}'
  {"status":"waiting","diagnostics":[],"truncated":true,"truncation_reason":"Results limited to 0 diagnostics due to token constraints","token_count":108,"summary":{"total_diagnostics":0,"returned_diagnostics":0,"error_count":0,"warning_count":0}}

  $ mcp --pipe test.sock call dune_build_status '{"max_diagnostics": 10}'  
  {"status":"waiting","diagnostics":[],"truncated":true,"truncation_reason":"Results limited to 0 diagnostics due to token constraints","token_count":108,"summary":{"total_diagnostics":0,"returned_diagnostics":0,"error_count":0,"warning_count":0}}

  $ mcp --pipe test.sock call dune_build_status '{"page": 0}'
  {"status":"waiting","diagnostics":[],"truncated":true,"truncation_reason":"Results limited to 0 diagnostics due to token constraints","token_count":108,"summary":{"total_diagnostics":0,"returned_diagnostics":0,"error_count":0,"warning_count":0}}

=== Cleanup ===
  $ kill $SERVER_PID 2>/dev/null || true
  $ kill -9 $DUNE_PID 2>/dev/null || true
  $ rm -f dune-project dune main.ml test.sock
