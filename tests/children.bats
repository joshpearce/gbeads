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

@test "children requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads children
  assert_failure
  assert_output --partial "Usage:"
}

@test "children with no flags lists children" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child 1" --parent 1 >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child 2" --parent 1 >/dev/null

  run_gbeads children 1
  assert_success
  assert_output --partial "Children:"
  assert_output --partial "#2"
  assert_output --partial "Child 1"
  assert_output --partial "#3"
  assert_output --partial "Child 2"
}

@test "children shows empty message when no children" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Standalone" >/dev/null

  run_gbeads children 1
  assert_success
  assert_output --partial "No children"
}

@test "children --add adds child to task list" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Orphan task" >/dev/null

  run_gbeads children 1 --add 2
  assert_success
  assert_output --partial "Added #2"

  # Verify parent has child in task list
  run gh issue view 1 --json body
  assert_output --partial "- [ ] #2 Orphan task"

  # Verify child has parent in frontmatter
  run gh issue view 2 --json body
  assert_output --partial "parent: 1"
}

@test "children --add handles multiple children" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 1" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 2" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 3" >/dev/null

  run_gbeads children 1 --add "2,3,4"
  assert_success
  assert_output --partial "Added #2"
  assert_output --partial "Added #3"
  assert_output --partial "Added #4"

  run_gbeads children 1
  assert_output --partial "#2"
  assert_output --partial "#3"
  assert_output --partial "#4"
}

@test "children --remove removes child from task list" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child" --parent 1 >/dev/null

  run_gbeads children 1 --remove 2
  assert_success
  assert_output --partial "Removed #2"

  # Verify child is not in parent's task list
  run gh issue view 1 --json body
  refute_output --partial "#2"

  # Verify child's parent is cleared
  run gh issue view 2 --json body
  assert_output --partial "parent: null"
}

@test "children --add skips nonexistent issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null

  run_gbeads children 1 --add 999
  assert_success
  assert_output --partial "not found"
}

@test "children fails for nonexistent parent" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads children 999
  assert_failure
  assert_output --partial "not found"
}
