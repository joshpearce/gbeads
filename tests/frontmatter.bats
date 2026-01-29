#!/usr/bin/env bats

load test_helper

@test "create_frontmatter generates valid YAML" {
  run bash -c "source $PROJECT_ROOT/gbeads; create_frontmatter"
  assert_success
  assert_line --index 0 "---"
  assert_output --partial "depends_on: []"
  assert_output --partial "claimed_by: null"
  assert_output --partial "parent: null"
}

@test "create_frontmatter accepts parent argument" {
  run bash -c "source $PROJECT_ROOT/gbeads; create_frontmatter 5"
  assert_success
  assert_output --partial "parent: 5"
}

@test "parse_frontmatter_field extracts claimed_by" {
  local body=$'---\ndepends_on: []\nclaimed_by: agent-001\nparent: null\n---\nBody text'
  run bash -c "source $PROJECT_ROOT/gbeads; parse_frontmatter_field '$body' 'claimed_by'"
  assert_success
  assert_output "agent-001"
}

@test "parse_frontmatter_field returns empty for missing field" {
  local body=$'---\ndepends_on: []\nclaimed_by: null\nparent: null\n---\nBody text'
  run bash -c "source $PROJECT_ROOT/gbeads; parse_frontmatter_field '$body' 'nonexistent'"
  assert_success
  assert_output ""
}

@test "parse_frontmatter_field returns empty when no frontmatter" {
  local body="Just plain body text"
  run bash -c "source $PROJECT_ROOT/gbeads; parse_frontmatter_field '$body' 'claimed_by'"
  assert_success
  assert_output ""
}

@test "update_frontmatter_field changes claimed_by" {
  local body=$'---\ndepends_on: []\nclaimed_by: null\nparent: null\n---\nBody text'
  run bash -c "source $PROJECT_ROOT/gbeads; update_frontmatter_field '$body' 'claimed_by' 'worker-123'"
  assert_success
  assert_output --partial "claimed_by: worker-123"
  assert_output --partial "Body text"
}

@test "update_frontmatter_field creates frontmatter if missing" {
  local body="Just plain body text"
  run bash -c "source $PROJECT_ROOT/gbeads; update_frontmatter_field '$body' 'claimed_by' 'worker-123'"
  assert_success
  assert_output --partial "---"
  assert_output --partial "claimed_by: worker-123"
  assert_output --partial "Just plain body text"
}

@test "get_body_content extracts text after frontmatter" {
  local body=$'---\ndepends_on: []\nclaimed_by: null\nparent: null\n---\nBody content here'
  run bash -c "source $PROJECT_ROOT/gbeads; get_body_content '$body'"
  assert_success
  assert_output "Body content here"
}

@test "get_body_content returns full text when no frontmatter" {
  local body="No frontmatter here"
  run bash -c "source $PROJECT_ROOT/gbeads; get_body_content '$body'"
  assert_success
  assert_output "No frontmatter here"
}
