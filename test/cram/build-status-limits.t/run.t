Test OCaml MCP Server dune_build_status enhanced API functionality

This test verifies that the dune_build_status tool uses the new enhanced API format
with summary information, token counting, and proper field structure.

=== Setup: Create a simple project ===

  $ cat > dune-project << EOF
  > (lang dune 3.0)
  > (name enhanced_test_project)
  > EOF

  $ cat > dune << EOF
  > (executable (name main))
  > EOF

  $ cat > main.ml << EOF
  > let () = print_endline "Hello from enhanced API test"
  > EOF

=== Start dune RPC and MCP server ===

  $ dune build --watch --root . &
  Success, waiting for filesystem changes...
  Success, waiting for filesystem changes...
  $ DUNE_PID=$!
  $ ocaml-mcp-server --pipe test.sock &
  $ SERVER_PID=$!
  $ sleep 2

=== Test 1: Enhanced API format has all required fields ===

  $ mcp --pipe test.sock call dune_build_status | jq 'keys | sort'
  [
    "diagnostics",
    "status",
    "summary",
    "token_count",
    "truncated",
    "truncation_reason"
  ]

=== Test 2: Summary object has proper structure ===

  $ mcp --pipe test.sock call dune_build_status | jq '.summary | keys | sort'
  [
    "error_count",
    "returned_diagnostics",
    "total_diagnostics",
    "warning_count"
  ]

=== Test 3: Enhanced API accepts new parameters ===

  $ mcp --pipe test.sock call dune_build_status '{"max_diagnostics": 10}' | jq 'has("summary")'
  true

=== Test 4: Enhanced API accepts severity filter ===

  $ mcp --pipe test.sock call dune_build_status '{"severity_filter": "error"}' | jq 'has("summary")'
  true

=== Test 5: Token count is calculated ===

  $ mcp --pipe test.sock call dune_build_status | jq '.token_count >= 0'
  true

=== Test 6: Status field is present ===

  $ mcp --pipe test.sock call dune_build_status | jq '.status | type'
  "string"

=== Test 7: Diagnostics array is present ===

  $ mcp --pipe test.sock call dune_build_status | jq '.diagnostics | type'
  "array"

=== Cleanup ===

  $ kill $SERVER_PID 2>/dev/null || true
  $ kill -9 $DUNE_PID 2>/dev/null || true
  $ rm -f dune-project dune main.ml test.sock
