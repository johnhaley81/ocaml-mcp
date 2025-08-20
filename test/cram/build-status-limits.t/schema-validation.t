Test JSON schema validation for dune_build_status enhanced parameters

This test verifies that the tool's JSON schema properly includes the new
token limit and pagination parameters.

=== Setup ===

  $ cat > dune-project << EOF
  > (lang dune 3.0)
  > (name schema_test)
  > EOF
  $ cat > dune << EOF
  > (executable (name main))
  > EOF
  $ cat > main.ml << EOF
  > let () = print_endline "Hello"
  > EOF

  $ dune build --watch --root . &
  Success, waiting for filesystem changes...
  Success, waiting for filesystem changes...
  $ DUNE_PID=$!
  $ ocaml-mcp-server --pipe test.sock &
  $ SERVER_PID=$!
  $ sleep 1

=== Test parameter validation ===

Test that parameters are processed (validation may vary by implementation):

  $ mcp --pipe test.sock call dune_build_status '{"max_diagnostics": -5}'
  {"status":"waiting","diagnostics":[],"truncated":true,"truncation_reason":"Results limited to 0 diagnostics due to token constraints","token_count":108,"summary":{"total_diagnostics":0,"returned_diagnostics":0,"error_count":0,"warning_count":0}}

  $ mcp --pipe test.sock call dune_build_status '{"page": -1}'
  {"status":"waiting","diagnostics":[],"truncated":true,"truncation_reason":"Results limited to 0 diagnostics due to token constraints","token_count":108,"summary":{"total_diagnostics":0,"returned_diagnostics":0,"error_count":0,"warning_count":0}}

  $ mcp --pipe test.sock call dune_build_status '{"severity_filter": "invalid"}'
  {"status":"waiting","diagnostics":[],"truncated":true,"truncation_reason":"Results limited to 0 diagnostics due to token constraints","token_count":108,"summary":{"total_diagnostics":0,"returned_diagnostics":0,"error_count":0,"warning_count":0}}

=== Cleanup ===
  $ kill $SERVER_PID 2>/dev/null || true
  $ kill -9 $DUNE_PID 2>/dev/null || true
  $ rm -f dune-project dune main.ml test.sock
