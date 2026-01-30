#!/usr/bin/env bats

load test_helper

@test "create_metadata generates valid HTML table" {
  run bash -c "source $PROJECT_ROOT/gbeads; create_metadata"
  assert_success
  assert_line --index 0 "<details>"
  assert_output --partial "<summary>Metadata</summary>"
  assert_output --partial "| depends_on | [] |"
  assert_output --partial "| claimed_by | null |"
  assert_output --partial "| parent | null |"
  assert_output --partial "</details>"
}

@test "create_metadata accepts parent argument" {
  run bash -c "source $PROJECT_ROOT/gbeads; create_metadata 5"
  assert_success
  assert_output --partial "| parent | 5 |"
}

@test "parse_metadata_field extracts claimed_by" {
  local body=$'<details>\n<summary>Metadata</summary>\n\n| Field | Value |\n|-------|-------|\n| depends_on | [] |\n| claimed_by | agent-001 |\n| parent | null |\n\n</details>\n\nBody text'
  run bash -c "source $PROJECT_ROOT/gbeads; parse_metadata_field '$body' 'claimed_by'"
  assert_success
  assert_output "agent-001"
}

@test "parse_metadata_field returns empty for missing field" {
  local body=$'<details>\n<summary>Metadata</summary>\n\n| Field | Value |\n|-------|-------|\n| depends_on | [] |\n| claimed_by | null |\n| parent | null |\n\n</details>\n\nBody text'
  run bash -c "source $PROJECT_ROOT/gbeads; parse_metadata_field '$body' 'nonexistent'"
  assert_success
  assert_output ""
}

@test "parse_metadata_field returns empty when no metadata" {
  local body="Just plain body text"
  run bash -c "source $PROJECT_ROOT/gbeads; parse_metadata_field '$body' 'claimed_by'"
  assert_success
  assert_output ""
}

@test "update_metadata_field changes claimed_by" {
  local body=$'<details>\n<summary>Metadata</summary>\n\n| Field | Value |\n|-------|-------|\n| depends_on | [] |\n| claimed_by | null |\n| parent | null |\n\n</details>\n\nBody text'
  run bash -c "source $PROJECT_ROOT/gbeads; update_metadata_field '$body' 'claimed_by' 'worker-123'"
  assert_success
  assert_output --partial "| claimed_by | worker-123 |"
  assert_output --partial "Body text"
}

@test "update_metadata_field creates metadata if missing" {
  local body="Just plain body text"
  run bash -c "source $PROJECT_ROOT/gbeads; update_metadata_field '$body' 'claimed_by' 'worker-123'"
  assert_success
  assert_output --partial "<details>"
  assert_output --partial "| claimed_by | worker-123 |"
  assert_output --partial "Just plain body text"
}

@test "get_body_content extracts text after metadata" {
  local body=$'<details>\n<summary>Metadata</summary>\n\n| Field | Value |\n|-------|-------|\n| depends_on | [] |\n| claimed_by | null |\n| parent | null |\n\n</details>\n\nBody content here'
  run bash -c "source $PROJECT_ROOT/gbeads; get_body_content '$body'"
  assert_success
  assert_output "Body content here"
}

@test "get_body_content returns full text when no metadata" {
  local body="No metadata here"
  run bash -c "source $PROJECT_ROOT/gbeads; get_body_content '$body'"
  assert_success
  assert_output "No metadata here"
}

@test "get_body_content excludes tasks section" {
  local body=$'<details>\n<summary>Metadata</summary>\n\n| Field | Value |\n|-------|-------|\n| depends_on | [] |\n| claimed_by | null |\n| parent | null |\n\n</details>\n\nUser description\n\n## Tasks\n- [ ] #1 Task one'
  run bash -c "source $PROJECT_ROOT/gbeads; get_body_content '$body'"
  assert_success
  assert_output "User description"
}
