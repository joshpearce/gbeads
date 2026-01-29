#!/usr/bin/env bats

load test_helper

@test "mock gh is in PATH" {
  run which gh
  assert_success
  [[ "$output" == *"mock_gh/gh"* ]]
}

@test "mock gh can create labels" {
  run gh label create "test-label" --description "A test label"
  assert_success
  assert_output --partial "Label created"
}

@test "mock gh can list labels as JSON" {
  gh label create "label-1" --description "First"
  run gh label list --json name
  assert_success
  assert_output --partial "label-1"
}

@test "mock gh can create issues" {
  run gh issue create --title "Test Issue" --body "Body"
  assert_success
  assert_output --partial "issues/1"
}

@test "mock gh can list issues as JSON" {
  gh issue create --title "Issue 1" --body "Body 1"
  gh issue create --title "Issue 2" --body "Body 2"
  run gh issue list --json number,title
  assert_success
  assert_output --partial "Issue 1"
  assert_output --partial "Issue 2"
}

@test "mock gh can view issue" {
  gh issue create --title "View Test" --body "View body"
  run gh issue view 1 --json number,title,body
  assert_success
  assert_output --partial "View Test"
}

@test "mock gh can edit issue" {
  gh issue create --title "Original" --body "Original body"
  run gh issue edit 1 --title "Updated"
  assert_success
  run gh issue view 1 --json title
  assert_output --partial "Updated"
}

@test "mock gh can close and reopen issue" {
  gh issue create --title "Lifecycle Test" --body "Body"
  run gh issue close 1
  assert_success
  run gh issue view 1 --json state
  assert_output --partial "closed"
  run gh issue reopen 1
  assert_success
  run gh issue view 1 --json state
  assert_output --partial "open"
}

@test "gbeads --help works" {
  run_gbeads --help
  assert_success
  assert_output --partial "gbeads - GitHub issue wrapper"
}

@test "gbeads --version works" {
  run_gbeads --version
  assert_success
  assert_output --partial "gbeads version"
}
