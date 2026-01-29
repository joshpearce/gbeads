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
}

@test "full workflow: init, create hierarchy, claim, update, close" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Initialize
  run_gbeads init
  assert_success

  # Create feature with stories and tasks
  run_gbeads create feature "User Authentication"
  assert_success

  run_gbeads create story "Login Flow" --parent 1
  assert_success

  run_gbeads create task "Build form" --parent 2
  assert_success

  run_gbeads create task "Add validation" --parent 2
  assert_success

  # Verify hierarchy
  run_gbeads children 1
  assert_output --partial "#2"

  run_gbeads children 2
  assert_output --partial "#3"
  assert_output --partial "#4"

  # Claim a task
  run_gbeads claim 3 worker-001
  assert_success

  # List unclaimed tasks
  run_gbeads list --type task --unclaimed
  assert_success
  assert_output --partial "#4"
  refute_output --partial "#3"

  # Update task title (should sync to parent)
  run_gbeads update 3 --title "Build login form"
  assert_success

  run_gbeads children 2
  assert_output --partial "Build login form"

  # Complete task
  run_gbeads close 3
  assert_success

  # Verify state
  run_gbeads show 3
  assert_output --partial "State:      closed"

  # Reopen if needed
  run_gbeads reopen 3
  assert_success

  run_gbeads show 3
  assert_output --partial "State:      open"
}

@test "children management: add orphans, remove children" {
  cd "$MOCK_GH_STATE/mock_repo"

  run_gbeads init
  assert_success

  # Create parent and orphan tasks
  run_gbeads create feature "Epic"
  run_gbeads create task "Orphan 1"
  run_gbeads create task "Orphan 2"
  assert_success

  # Add orphans as children
  run_gbeads children 1 --add "2,3"
  assert_success

  run_gbeads children 1
  assert_output --partial "#2"
  assert_output --partial "#3"

  # Verify children have parent set
  run_gbeads show 2
  assert_output --partial "Parent:     1"

  # Remove a child
  run_gbeads children 1 --remove 2
  assert_success

  run_gbeads children 1
  refute_output --partial "#2"
  assert_output --partial "#3"

  # Verify removed child has no parent
  run_gbeads show 2
  assert_output --partial "Parent:     null"
}
