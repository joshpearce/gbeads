#!/usr/bin/env bats

load test_helper

# Clean test state at start of file (persists for inspection after tests)
setup_file() {
  rm -rf "$TEST_DIR/test_data"
  mkdir -p "$TEST_DIR/test_data"
}

setup() {
  # Clean and recreate test_data for each test
  rm -rf "$MOCK_GH_STATE"
  mkdir -p "$MOCK_GH_STATE"

  # Create a mock git repo for each test
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git" 2>/dev/null || git remote set-url origin "git@github.com:test/repo.git"

  # Initialize labels and create a test issue
  "$PROJECT_ROOT/gbeads" init >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null
}

# Claim tests

@test "claim requires number and worker-id" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads claim
  assert_failure
  assert_output --partial "Usage:"

  run_gbeads claim 1
  assert_failure
  assert_output --partial "Usage:"
}

@test "claim sets claimed_by in metadata" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads claim 1 agent-001
  assert_success
  assert_output --partial "Claimed issue #1 for agent-001"

  run gh issue view 1 --json body
  assert_output --partial "claimed_by | agent-001"
}

@test "claim fails if already claimed" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" claim 1 agent-001 >/dev/null

  run_gbeads claim 1 agent-002
  assert_failure
  assert_output --partial "already claimed"
}

@test "claim fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads claim 999 agent-001
  assert_failure
  assert_output --partial "not found"
}

# Unclaim tests

@test "unclaim requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads unclaim
  assert_failure
  assert_output --partial "Usage:"
}

@test "unclaim clears claimed_by" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" claim 1 agent-001 >/dev/null

  run_gbeads unclaim 1
  assert_success
  assert_output --partial "Released claim"

  run gh issue view 1 --json body
  assert_output --partial "claimed_by | null"
}

@test "unclaim on unclaimed issue is idempotent" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads unclaim 1
  assert_success
  assert_output --partial "not claimed"
}

# Close tests

@test "close requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads close
  assert_failure
  assert_output --partial "Usage:"
}

@test "close closes the issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads close 1
  assert_success
  assert_output --partial "Closed issue #1"

  run gh issue view 1 --json state
  assert_output --partial "closed"
}

@test "close fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads close 999
  assert_failure
}

# Reopen tests

@test "reopen requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads reopen
  assert_failure
  assert_output --partial "Usage:"
}

@test "reopen reopens closed issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" close 1 >/dev/null

  run_gbeads reopen 1
  assert_success
  assert_output --partial "Reopened issue #1"

  run gh issue view 1 --json state
  assert_output --partial "open"
}

# Integration test

@test "full claim lifecycle works" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Claim
  run_gbeads claim 1 worker-123
  assert_success

  # Verify claimed in show
  run_gbeads show 1
  assert_output --partial "Claimed by: worker-123"

  # Unclaim
  run_gbeads unclaim 1
  assert_success

  # Verify unclaimed
  run_gbeads show 1
  assert_output --partial "Claimed by: null"
}

@test "full close/reopen lifecycle works" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Close
  run_gbeads close 1
  assert_success

  # Verify closed
  run_gbeads show 1
  assert_output --partial "State:      closed"

  # Reopen
  run_gbeads reopen 1
  assert_success

  # Verify open
  run_gbeads show 1
  assert_output --partial "State:      open"
}
