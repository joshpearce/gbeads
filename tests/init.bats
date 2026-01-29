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

@test "init creates all four type labels" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads init
  assert_success
  assert_output --partial "type: feature"
  assert_output --partial "type: user story"
  assert_output --partial "type: task"
  assert_output --partial "type: bug"
}

@test "init reports labels already exist on second run" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads init
  assert_success

  run_gbeads init
  assert_success
  assert_output --partial "Exists:"
}

@test "init creates labels in mock gh state" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads init
  assert_success

  run gh label list --json name
  assert_success
  assert_output --partial "type: feature"
  assert_output --partial "type: user story"
  assert_output --partial "type: task"
  assert_output --partial "type: bug"
}

@test "init fails when not in git repo" {
  cd /tmp
  run_gbeads init
  assert_failure
  assert_output --partial "Not in a git repository"
}
