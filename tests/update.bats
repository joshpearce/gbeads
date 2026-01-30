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

@test "update requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads update
  assert_failure
  assert_output --partial "Usage:"
}

@test "update requires --title or --type" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Original" >/dev/null

  run_gbeads update 1
  assert_failure
  assert_output --partial "Must specify --title, --type, or --body"
}

@test "update --title changes issue title" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Original title" >/dev/null

  run_gbeads update 1 --title "New title"
  assert_success
  assert_output --partial "Updated title to: New title"

  run gh issue view 1 --json title
  assert_output --partial "New title"
}

@test "update --type changes issue label" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "A task" >/dev/null

  run_gbeads update 1 --type bug
  assert_success
  assert_output --partial "Updated type to: bug"

  run gh issue view 1 --json labels
  assert_output --partial "type: bug"
  refute_output --partial "type: task"
}

@test "update validates type" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "A task" >/dev/null

  run_gbeads update 1 --type invalid
  assert_failure
  assert_output --partial "Invalid type"
}

@test "update --title and --type together" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Original" >/dev/null

  run_gbeads update 1 --title "New name" --type feature
  assert_success
  assert_output --partial "Updated title"
  assert_output --partial "Updated type"

  run gh issue view 1 --json title,labels
  assert_output --partial "New name"
  assert_output --partial "type: feature"
}

@test "update fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads update 999 --title "Test"
  assert_failure
  assert_output --partial "not found"
}

# Parent sync tests

@test "update --title syncs to parent task list" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Create parent and child
  "$PROJECT_ROOT/gbeads" create feature "Parent feature" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Original child title" --parent 1 >/dev/null

  # Verify child is in parent's task list
  run gh issue view 1 --json body
  assert_output --partial "- [ ] #2 Original child title"

  # Update child's title
  run_gbeads update 2 --title "Updated child title"
  assert_success
  assert_output --partial "Synced title to parent #1"

  # Verify parent's task list is updated
  run gh issue view 1 --json body
  assert_output --partial "- [ ] #2 Updated child title"
  refute_output --partial "Original child title"
}

@test "update --title on issue without parent does not fail" {
  cd "$MOCK_GH_STATE/mock_repo"

  "$PROJECT_ROOT/gbeads" create task "Standalone task" >/dev/null

  run_gbeads update 1 --title "New title"
  assert_success
  refute_output --partial "Synced title to parent"
}

@test "update --type does not sync to parent" {
  cd "$MOCK_GH_STATE/mock_repo"

  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child" --parent 1 >/dev/null

  # Change type only
  run_gbeads update 2 --type bug
  assert_success
  refute_output --partial "Synced title"
}

@test "update --body changes description" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "A task" --body "Original description" >/dev/null

  run_gbeads update 1 --body "New description"
  assert_success
  assert_output --partial "Updated body description"

  run gh issue view 1 --json body
  assert_output --partial "New description"
  refute_output --partial "Original description"
}

@test "update --body preserves metadata" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "A task" >/dev/null

  # Claim the issue first (to have non-default metadata)
  "$PROJECT_ROOT/gbeads" claim 1 worker-abc >/dev/null

  run_gbeads update 1 --body "Added description"
  assert_success

  # Verify metadata preserved
  run gh issue view 1 --json body
  assert_output --partial "| claimed_by | worker-abc |"
  assert_output --partial "Added description"
}

@test "update --body preserves tasks section" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Create parent with body
  "$PROJECT_ROOT/gbeads" create feature "Parent" --body "Parent description" >/dev/null

  # Add child (creates tasks section)
  "$PROJECT_ROOT/gbeads" create task "Child" --parent 1 >/dev/null

  # Update parent body
  run_gbeads update 1 --body "Updated parent description"
  assert_success

  # Verify tasks preserved
  run gh issue view 1 --json body
  assert_output --partial "Updated parent description"
  assert_output --partial "## Tasks"
  assert_output --partial "- [ ] #2 Child"
}

@test "update --body and --title together" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Original" >/dev/null

  run_gbeads update 1 --title "New title" --body "New description"
  assert_success
  assert_output --partial "Updated title"
  assert_output --partial "Updated body"

  run gh issue view 1 --json title,body
  assert_output --partial "New title"
  assert_output --partial "New description"
}
