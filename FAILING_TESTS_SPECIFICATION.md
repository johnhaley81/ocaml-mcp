# Test-Driven Development Specification: dune_build_status Token Limit Functionality

## Test Status: RED Phase (All Tests Failing as Expected)

This document specifies the comprehensive failing unit tests created for implementing token limit functionality in the `dune_build_status` tool. All tests are currently failing by design, defining the expected behavior that needs to be implemented.

## Test Results Summary

**Test Execution**: `dune exec test/unit/test_build_status_limits.exe`
**Total Tests**: 8
**Failed Tests**: 8 (expected in RED phase) 
**Passed Tests**: 0 (as expected in TDD RED phase)
**Status**: ✅ ALL TESTS FAILED AS EXPECTED - Ready for implementation phase

## Test Specifications

### 1. Token Limit Enforcement
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:54-68`
**Expected Behavior**: Response should stay under 25,000 tokens
**Current Status**: FAILING - Enhanced Args type with token limit fields does not exist
**Requirements**:
- Add `max_diagnostics : int option` field to Args type
- Add `page : int option` field to Args type  
- Add `severity_filter : string option` field to Args type
- Add `file_pattern : string option` field to Args type

### 2. Error Prioritization
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:72-94`
**Expected Behavior**: Errors should appear before warnings when results are limited
**Current Status**: FAILING - Error prioritization not implemented - errors not first
**Requirements**:
- Implement sorting logic to prioritize errors over warnings
- Ensure diagnostic ordering: errors first, then warnings
- Apply prioritization when limiting results

### 3. Pagination Support
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:98-125`
**Expected Behavior**: Should support page parameter with next_cursor
**Current Status**: FAILING - Enhanced Output type with pagination fields does not exist
**Requirements**:
- Add `next_cursor : string option` field to Output type
- Add `truncated : bool` field to Output type
- Add `token_count : int` field to Output type
- Implement pagination logic for page parameter

### 4. Diagnostic Filtering
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:129-143`
**Expected Behavior**: Should filter diagnostics by severity and file pattern
**Current Status**: FAILING - Filtering fields in Args type not implemented
**Requirements**:
- Implement severity filtering (e.g., "error" only)
- Implement file pattern filtering (e.g., "src/**/*.ml")
- Add filtering logic to execute function

### 5. Summary Information
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:147-172`
**Expected Behavior**: Should include diagnostic counts and build summary
**Current Status**: FAILING - Summary information structure not implemented
**Requirements**:
- Add `summary : summary` field to Output type
- Implement summary type with diagnostic counts
- Include build status information in summary
- Track total vs returned diagnostic counts

### 6. Truncation Indication
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:176-192`
**Expected Behavior**: Should indicate when results are truncated and why
**Current Status**: FAILING - Truncation indication fields not implemented
**Requirements**:
- Add `truncation_reason : string option` field to Output type
- Support reasons: "token_limit", "max_diagnostics_limit"
- Clearly indicate when and why truncation occurs

### 7. Enhanced Args Schema
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:196-211`
**Expected Behavior**: Args schema should include new fields for token limits
**Current Status**: FAILING - Enhanced Args schema not implemented
**Requirements**:
- Update Args.schema() function to include new fields
- Add schema definitions for: max_diagnostics, page, severity_filter, file_pattern
- Ensure JSON schema validation works

### 8. Token Counting
**File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml:215-227`
**Expected Behavior**: Should accurately count tokens in response
**Current Status**: FAILING - Token counting functionality not implemented
**Requirements**:
- Implement token counting algorithm
- Count tokens in diagnostic messages, file paths, and metadata
- Use token count to enforce 25,000 token limit

## Expected Type Definitions

### Enhanced Args Type
```ocaml
module Args = struct
  type t = { 
    targets : string list option [@default None];
    max_diagnostics : int option [@default None];
    page : int option [@default None];
    severity_filter : string option [@default None];
    file_pattern : string option [@default None];
  } [@@deriving yojson]
end
```

### Enhanced Output Type
```ocaml
module Output = struct
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
  
  type summary = {
    total_diagnostics : int;
    returned_diagnostics : int;
    error_count : int;
    warning_count : int;
    build_summary : build_summary option;
  }
  
  type t = { 
    status : string; 
    diagnostics : diagnostic list;
    truncated : bool;
    truncation_reason : string option;
    next_cursor : string option;
    token_count : int;
    summary : summary;
  } [@@deriving yojson]
end
```

## Implementation Steps (Next Phase - GREEN)

1. **Implement enhanced Args type with new fields**
   - Add max_diagnostics, page, severity_filter, file_pattern fields
   - Update schema generation
   - Update JSON serialization/deserialization

2. **Implement enhanced Output type with summary and pagination**
   - Add all new Output fields
   - Implement summary type with diagnostic counts
   - Add pagination and truncation fields

3. **Add token counting and limiting logic**
   - Implement token counting algorithm
   - Add logic to limit responses to 25,000 tokens
   - Truncate results when necessary

4. **Add error prioritization logic**
   - Sort diagnostics to put errors before warnings
   - Apply prioritization when limiting results

5. **Implement pagination and filtering**
   - Add pagination logic for page parameter
   - Implement severity and file pattern filtering
   - Generate next_cursor for pagination

6. **Add truncation indication**
   - Set truncated flag when results are limited
   - Include truncation_reason (token_limit or max_diagnostics_limit)
   - Provide clear truncation metadata

## Test Files

- **Main Test File**: `/home/me/external-repos/ocaml-mcp/test/unit/test_build_status_limits.ml`
- **Dune Configuration**: `/home/me/external-repos/ocaml-mcp/test/unit/dune`
- **Target Implementation**: `/home/me/external-repos/ocaml-mcp/lib/ocaml-mcp-server/tools/build_status.ml`

## Validation

To verify RED phase completion:
```bash
dune exec test/unit/test_build_status_limits.exe
```

Expected output: All 8 tests should fail with clear descriptions of missing functionality.

Once implementation begins (GREEN phase), tests should be run after each change to guide development toward the expected behavior.