#!/usr/bin/env bats

load test_helper

setup() {
  rm -rf "$MOCK_GH_STATE"
  mkdir -p "$MOCK_GH_STATE"
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git" 2>/dev/null || git remote set-url origin "git@github.com:test/repo.git"
  "$PROJECT_ROOT/gbeads" init >/dev/null
}

@test "ready shows no work when no issues exist" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads ready
  assert_success
  assert_output "No available work."
}

@test "ready shows unclaimed unblocked issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "First task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Second task" >/dev/null

  run_gbeads ready
  assert_success
  assert_output --partial "#1"
  assert_output --partial "First task"
  assert_output --partial "#2"
  assert_output --partial "Second task"
}

@test "ready hides claimed issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Unclaimed task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Claimed task" >/dev/null
  "$PROJECT_ROOT/gbeads" claim 2 agent-001 >/dev/null

  run_gbeads ready
  assert_success
  assert_output --partial "#1"
  assert_output --partial "Unclaimed task"
  refute_output --partial "#2"
  refute_output --partial "Claimed task"
}

@test "ready hides issues with open dependencies" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Dependency task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Blocked task" >/dev/null
  "$PROJECT_ROOT/gbeads" depends 2 --add 1 >/dev/null

  run_gbeads ready
  assert_success
  # Issue #1 should show (no dependencies)
  assert_output --partial "#1"
  assert_output --partial "Dependency task"
  # Issue #2 should NOT show (blocked by #1)
  refute_output --partial "Blocked task"
}

@test "ready shows issues with all closed dependencies" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Dependency task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Was blocked task" >/dev/null
  "$PROJECT_ROOT/gbeads" depends 2 --add 1 >/dev/null

  # Close the dependency
  "$PROJECT_ROOT/gbeads" close 1 >/dev/null

  run_gbeads ready
  assert_success
  # Issue #2 should now show (dependency is closed)
  assert_output --partial "#2"
  assert_output --partial "Was blocked task"
  # Issue #1 should NOT show (it's closed)
  refute_output --partial "Dependency task"
}

@test "ready hides closed issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Open task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Closed task" >/dev/null
  "$PROJECT_ROOT/gbeads" close 2 >/dev/null

  run_gbeads ready
  assert_success
  assert_output --partial "#1"
  assert_output --partial "Open task"
  refute_output --partial "Closed task"
}

@test "ready shows issue type in output" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "A feature" >/dev/null
  "$PROJECT_ROOT/gbeads" create bug "A bug" >/dev/null

  run_gbeads ready
  assert_success
  assert_output --partial "feature"
  assert_output --partial "bug"
}

@test "ready shows empty message when all issues are claimed" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Task one" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task two" >/dev/null
  "$PROJECT_ROOT/gbeads" claim 1 agent-001 >/dev/null
  "$PROJECT_ROOT/gbeads" claim 2 agent-002 >/dev/null

  run_gbeads ready
  assert_success
  assert_output "No available work."
}

@test "ready shows empty message when all issues are blocked" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Blocker" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Blocked one" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Blocked two" >/dev/null
  "$PROJECT_ROOT/gbeads" depends 2 --add 1 >/dev/null
  "$PROJECT_ROOT/gbeads" depends 3 --add 1 >/dev/null

  # Claim the only unblocked issue
  "$PROJECT_ROOT/gbeads" claim 1 agent-001 >/dev/null

  run_gbeads ready
  assert_success
  assert_output "No available work."
}
