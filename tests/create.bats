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

@test "create requires type and title" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads create
  assert_failure
  assert_output --partial "Usage:"
}

@test "create validates type" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads create invalid "Test title"
  assert_failure
  assert_output --partial "Invalid type"
}

@test "create task creates issue with correct label" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads create task "Test task"
  assert_success
  assert_output --partial "Created task #1"

  run gh issue view 1 --json labels
  assert_output --partial "type: task"
}

@test "create feature creates issue with feature label" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads create feature "New feature"
  assert_success
  assert_output --partial "Created feature #1"

  run gh issue view 1 --json labels
  assert_output --partial "type: feature"
}

@test "create story creates issue with user story label" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads create story "User story"
  assert_success

  run gh issue view 1 --json labels
  assert_output --partial "type: user story"
}

@test "create bug creates issue with bug label" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads create bug "Bug report"
  assert_success

  run gh issue view 1 --json labels
  assert_output --partial "type: bug"
}

@test "create adds frontmatter to body" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads create task "Test task"
  assert_success

  run gh issue view 1 --json body
  assert_output --partial "depends_on:"
  assert_output --partial "claimed_by:"
  assert_output --partial "parent: null"
}

@test "create with --parent sets parent in frontmatter" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Create parent feature
  run_gbeads create feature "Parent feature"
  assert_success

  # Create child task
  run_gbeads create task "Child task" --parent 1
  assert_success
  assert_output --partial "Added to parent #1"

  # Verify child has parent in frontmatter
  run gh issue view 2 --json body
  assert_output --partial "parent: 1"
}

@test "create with --parent adds entry to parent task list" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Create parent feature
  run_gbeads create feature "Parent feature"
  assert_success

  # Create child task
  run_gbeads create task "Child task" --parent 1
  assert_success

  # Verify parent has child in task list
  run gh issue view 1 --json body
  assert_output --partial "## Tasks"
  assert_output --partial "- [ ] #2 Child task"
}
