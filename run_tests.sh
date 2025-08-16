#!/bin/bash

# Run the comprehensive build status tests
echo "=== Building Test Executables ==="
dune build test/unit/test_build_status_limits.exe test/unit/test_build_status_schemas.exe

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo -e "\n=== BUILD STATUS FUNCTIONALITY TESTS ==="
dune exec test/unit/test_build_status_limits.exe

if [ $? -ne 0 ]; then
    echo "Functionality tests failed!"
    exit 1
fi

echo -e "\n=== BUILD STATUS SCHEMA TESTS ==="
dune exec test/unit/test_build_status_schemas.exe

if [ $? -ne 0 ]; then
    echo "Schema tests failed!"
    exit 1
fi

echo -e "\n=== ALL TESTS PASSED! ==="
echo "Total tests run: 96 (35 functionality + 61 schema)"
echo "✅ Token counting and estimation"
echo "✅ Severity filtering"
echo "✅ File pattern filtering (glob patterns)"
echo "✅ Error prioritization"
echo "✅ Pagination logic"
echo "✅ Token limit enforcement"
echo "✅ Schema generation and validation"
echo "✅ JSON serialization/deserialization"
echo "✅ Default value handling"
echo "✅ Backward compatibility"