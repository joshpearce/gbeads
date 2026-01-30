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

@test "depends requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads depends
  assert_failure
  assert_output --partial "Usage:"
}

@test "depends fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads depends 999
  assert_failure
  assert_output --partial "not found"
}

@test "depends shows empty dependencies" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null

  run_gbeads depends 1
  assert_success
  assert_output --partial "Issue #1: Test task"
  assert_output --partial "Dependencies: none"
}

@test "depends --add adds single dependency" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "First task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Second task" >/dev/null

  run_gbeads depends 2 --add 1
  assert_success
  assert_output --partial "Added dependency: #1"

  # Verify metadata updated
  run gh issue view 2 --json body
  assert_output --partial "depends_on | [1]"
}

@test "depends --add adds multiple dependencies" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "First" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Second" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Third" >/dev/null

  run_gbeads depends 3 --add 1,2
  assert_success
  assert_output --partial "Added dependency: #1"
  assert_output --partial "Added dependency: #2"

  # Verify metadata updated
  run gh issue view 3 --json body
  assert_output --partial "depends_on | [1, 2]"
}

@test "depends --add prevents self-dependency" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null

  run_gbeads depends 1 --add 1
  assert_failure
  assert_output --partial "cannot depend on itself"
}

@test "depends --add validates dependency exists" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null

  run_gbeads depends 1 --add 999
  assert_output --partial "not found"
}

@test "depends --add is idempotent" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "First" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Second" >/dev/null

  # Add once
  "$PROJECT_ROOT/gbeads" depends 2 --add 1 >/dev/null

  # Add again - should be no-op
  run_gbeads depends 2 --add 1
  assert_success

  # Still just [1]
  run gh issue view 2 --json body
  assert_output --partial "depends_on | [1]"
}

@test "depends --remove removes dependency" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "First" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Second" >/dev/null

  # Add then remove
  "$PROJECT_ROOT/gbeads" depends 2 --add 1 >/dev/null

  run_gbeads depends 2 --remove 1
  assert_success
  assert_output --partial "Removed dependency: #1"

  # Verify empty
  run gh issue view 2 --json body
  assert_output --partial "depends_on | []"
}

@test "depends --remove ignores missing dependency" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null

  # Remove non-existent dependency - should be no-op
  run_gbeads depends 1 --remove 999
  assert_success
  assert_output --partial "Removed dependency: #999"
}

@test "depends shows existing dependencies with titles" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "First task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Second task" >/dev/null

  # Add dependency
  "$PROJECT_ROOT/gbeads" depends 2 --add 1 >/dev/null

  run_gbeads depends 2
  assert_success
  assert_output --partial "Issue #2: Second task"
  assert_output --partial "Dependencies: #1 (First task)"
}

@test "depends --add and --remove together" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "First" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Second" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Third" >/dev/null

  # Add initial dependency
  "$PROJECT_ROOT/gbeads" depends 3 --add 1 >/dev/null

  # Add #2, remove #1
  run_gbeads depends 3 --add 2 --remove 1
  assert_success

  # Verify result
  run gh issue view 3 --json body
  assert_output --partial "depends_on | [2]"
  refute_output --partial "depends_on | [1"
}
