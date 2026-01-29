#!/usr/bin/env bash
# test_helper.bash - Shared setup for bats tests

# Load bats helpers
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Get the directory containing this helper
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# State directory for mock gh
export MOCK_GH_STATE="$TEST_DIR/test_data"

# Add mock gh to PATH (before real gh)
export PATH="$TEST_DIR/mock_gh:$PATH"

# Setup function called before each test
setup() {
  # Clean and recreate test_data for each test
  rm -rf "$MOCK_GH_STATE"
  mkdir -p "$MOCK_GH_STATE"
}

# Setup function called once before all tests in a file
setup_file() {
  # Clean test_data at the start of each test file
  rm -rf "$TEST_DIR/test_data"
  mkdir -p "$TEST_DIR/test_data"
}

# Helper to run gbeads command
run_gbeads() {
  run "$PROJECT_ROOT/gbeads" "$@"
}

# Helper to check mock gh state files
get_issues() {
  cat "$MOCK_GH_STATE/issues.json" 2>/dev/null || echo "[]"
}

get_labels() {
  cat "$MOCK_GH_STATE/labels.json" 2>/dev/null || echo "[]"
}
