#!/usr/bin/env bats

load test_helper

@test "has_task_list returns true when present" {
  local body=$'Some text\n\n## Tasks\n- [ ] #1 First task'
  run bash -c "source $PROJECT_ROOT/gbeads; has_task_list '$body' && echo yes"
  assert_success
  assert_output "yes"
}

@test "has_task_list returns false when absent" {
  local body="No task list here"
  run bash -c "source $PROJECT_ROOT/gbeads; has_task_list '$body' && echo yes || echo no"
  assert_success
  assert_output "no"
}

@test "add_task_list_entry adds to existing list" {
  local body=$'## Tasks\n- [ ] #1 First task'
  run bash -c "source $PROJECT_ROOT/gbeads; add_task_list_entry '$body' 2 'Second task'"
  assert_success
  assert_output --partial "- [ ] #1 First task"
  assert_output --partial "- [ ] #2 Second task"
}

@test "add_task_list_entry creates new list when none exists" {
  local body="Just body text"
  run bash -c "source $PROJECT_ROOT/gbeads; add_task_list_entry '$body' 1 'First task'"
  assert_success
  assert_output --partial "Just body text"
  assert_output --partial "## Tasks"
  assert_output --partial "- [ ] #1 First task"
}

@test "remove_task_list_entry removes unchecked entry" {
  local body=$'## Tasks\n- [ ] #1 First task\n- [ ] #2 Second task'
  run bash -c "source $PROJECT_ROOT/gbeads; remove_task_list_entry '$body' 1"
  assert_success
  refute_output --partial "- [ ] #1"
  assert_output --partial "- [ ] #2 Second task"
}

@test "remove_task_list_entry removes checked entry" {
  local body=$'## Tasks\n- [x] #1 Done task\n- [ ] #2 Second task'
  run bash -c "source $PROJECT_ROOT/gbeads; remove_task_list_entry '$body' 1"
  assert_success
  refute_output --partial "#1"
  assert_output --partial "- [ ] #2 Second task"
}

@test "update_task_list_title changes title" {
  local body=$'## Tasks\n- [ ] #1 Old title\n- [ ] #2 Other task'
  run bash -c "source $PROJECT_ROOT/gbeads; update_task_list_title '$body' 1 'New title'"
  assert_success
  assert_output --partial "- [ ] #1 New title"
  assert_output --partial "- [ ] #2 Other task"
}

@test "parse_task_list extracts entries" {
  local body=$'## Tasks\n- [ ] #1 First task\n- [x] #2 Done task'
  run bash -c "source $PROJECT_ROOT/gbeads; parse_task_list '$body'"
  assert_success
  assert_line --index 0 "1|First task|false"
  assert_line --index 1 "2|Done task|true"
}
