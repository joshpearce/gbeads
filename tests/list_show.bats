#!/usr/bin/env bats

load test_helper

setup() {
  # Clean and recreate test_data for each test
  rm -rf "$MOCK_GH_STATE"
  mkdir -p "$MOCK_GH_STATE"

  # Create a mock git repo for each test
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git" 2>/dev/null || git remote set-url origin "git@github.com:test/repo.git"

  # Initialize labels
  "$PROJECT_ROOT/gbeads" init >/dev/null
}

@test "list shows header when no issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads list
  assert_success
  assert_output --partial "No issues found"
}

@test "list displays issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null
  "$PROJECT_ROOT/gbeads" create feature "Test feature" >/dev/null

  run_gbeads list
  assert_success
  assert_output --partial "Test task"
  assert_output --partial "Test feature"
}

@test "list --type filters by type" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "A task" >/dev/null
  "$PROJECT_ROOT/gbeads" create feature "A feature" >/dev/null

  run_gbeads list --type task
  assert_success
  assert_output --partial "A task"
  refute_output --partial "A feature"
}

@test "list --unclaimed filters unclaimed issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Unclaimed task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Claimed task" >/dev/null

  # Claim the second task (would need claim command, skip for now)
  # For this test, we verify unclaimed shows all when none are claimed
  run_gbeads list --unclaimed
  assert_success
  assert_output --partial "Unclaimed task"
  assert_output --partial "Claimed task"
}

@test "list --claimed-by filters by worker id" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Task 1" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 2" >/dev/null
  # TODO: Enhance this test when claim command is implemented in Phase 6
  # Once claim is available, this test should:
  #   1. Claim task 1 to agent-001
  #   2. Verify list --claimed-by agent-001 shows only task 1
  #   3. Verify list --claimed-by agent-002 shows neither task
  # For now, just verify the flag doesn't cause errors
  run_gbeads list --claimed-by agent-001
  assert_success
}

@test "list validates type" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads list --type invalid
  assert_failure
  assert_output --partial "Invalid type"
}

@test "show displays issue details" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Show test task" >/dev/null

  run_gbeads show 1
  assert_success
  assert_output --partial "Issue #1"
  assert_output --partial "Show test task"
  assert_output --partial "Type:       task"
  assert_output --partial "State:      open"
}

@test "show displays frontmatter fields" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child" --parent 1 >/dev/null

  run_gbeads show 2
  assert_success
  assert_output --partial "Parent:     1"
}

@test "show fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads show 999
  assert_failure
  assert_output --partial "not found"
}

@test "show requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads show
  assert_failure
  assert_output --partial "Usage:"
}
