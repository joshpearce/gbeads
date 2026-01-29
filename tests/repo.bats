#!/usr/bin/env bats

load test_helper

# Helper to create a mock git repo
setup_mock_git_repo() {
  local repo_dir="$MOCK_GH_STATE/mock_repo"
  mkdir -p "$repo_dir"
  cd "$repo_dir"
  git init -q
  git remote add origin "$1"
}

@test "get_repo extracts owner/repo from SSH remote" {
  setup_mock_git_repo "git@github.com:owner/repo.git"
  run bash -c "cd $MOCK_GH_STATE/mock_repo && . $PROJECT_ROOT/gbeads; get_repo"
  assert_success
  assert_output "owner/repo"
}

@test "get_repo extracts owner/repo from HTTPS remote" {
  setup_mock_git_repo "https://github.com/owner/repo.git"
  run bash -c "cd $MOCK_GH_STATE/mock_repo && . $PROJECT_ROOT/gbeads; get_repo"
  assert_success
  assert_output "owner/repo"
}

@test "get_repo handles remote without .git suffix" {
  setup_mock_git_repo "https://github.com/owner/repo"
  run bash -c "cd $MOCK_GH_STATE/mock_repo && . $PROJECT_ROOT/gbeads; get_repo"
  assert_success
  assert_output "owner/repo"
}

@test "get_repo fails when not in git repo" {
  cd /tmp
  run bash -c ". $PROJECT_ROOT/gbeads; get_repo"
  assert_failure
}

@test "require_repo sets REPO variable" {
  setup_mock_git_repo "git@github.com:test/project.git"
  run bash -c "cd $MOCK_GH_STATE/mock_repo && . $PROJECT_ROOT/gbeads; require_repo; echo \$REPO"
  assert_success
  assert_output "test/project"
}

@test "require_repo fails when not in git repo" {
  cd /tmp
  run bash -c ". $PROJECT_ROOT/gbeads; require_repo"
  assert_failure
  assert_output --partial "Not in a git repository"
}
