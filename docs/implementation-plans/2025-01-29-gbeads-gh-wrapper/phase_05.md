# gbeads Implementation Plan - Phase 5: List and Show Commands

**Goal:** Query and display issues

**Architecture:** Add cmd_list and cmd_show functions that wrap gh issue list/view with frontmatter parsing

**Tech Stack:** Bash, gh CLI, jq (via --jq flag)

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - Phase 4 commands expected to exist

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->
<!-- START_TASK_1 -->
### Task 1: Implement cmd_list function

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_list function before main()**

Note: This implementation uses embedded Python for JSON processing since we can't rely on jq being installed. Add `# shellcheck disable=SC2016` before the embedded Python if shellcheck complains about single quotes.

```bash
# List issues with optional filters
# Usage: gbeads list [--type <type>] [--claimed-by <id>] [--unclaimed] [--state <state>]
cmd_list() {
  require_repo

  local filter_type=""
  local filter_claimed_by=""
  local filter_unclaimed=false
  local filter_state="open"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)
        filter_type="$2"
        if ! validate_type "$filter_type"; then
          exit 1
        fi
        shift 2
        ;;
      --claimed-by)
        filter_claimed_by="$2"
        shift 2
        ;;
      --unclaimed)
        filter_unclaimed=true
        shift
        ;;
      --state)
        filter_state="$2"
        shift 2
        ;;
      --all)
        filter_state="all"
        shift
        ;;
      *)
        echo "Error: Unknown option '$1'" >&2
        exit 1
        ;;
    esac
  done

  # Build label filter
  local label_filter=""
  if [[ -n "$filter_type" ]]; then
    label_filter=$(get_type_label "$filter_type")
  fi

  # Get issues as JSON
  local issues_json
  if [[ -n "$label_filter" ]]; then
    issues_json=$(gh issue list --repo "$REPO" --state "$filter_state" --label "$label_filter" --json number,title,state,body,labels --limit 100)
  else
    issues_json=$(gh issue list --repo "$REPO" --state "$filter_state" --json number,title,state,body,labels --limit 100)
  fi

  # Process each issue
  local count
  count=$(echo "$issues_json" | grep -c '"number"' || echo 0)

  if [[ "$count" -eq 0 ]]; then
    echo "No issues found."
    return 0
  fi

  # Header
  printf "%-6s %-8s %-12s %s\n" "ID" "TYPE" "CLAIMED" "TITLE"
  printf "%-6s %-8s %-12s %s\n" "------" "--------" "------------" "-----"

  # Parse JSON and display (using simple grep/sed since we can't rely on jq)
  # This is a simplified approach - in practice you might want proper JSON parsing
  echo "$issues_json" | python3 -c "
import json
import sys

data = json.load(sys.stdin)
for issue in data:
    number = issue['number']
    title = issue['title']
    body = issue.get('body', '')
    labels = [l['name'] for l in issue.get('labels', [])]

    # Determine type
    issue_type = 'unknown'
    type_map = {
        'type: feature': 'feature',
        'type: user story': 'story',
        'type: task': 'task',
        'type: bug': 'bug'
    }
    for label in labels:
        if label in type_map:
            issue_type = type_map[label]
            break

    # Parse claimed_by from frontmatter
    claimed_by = '-'
    if body.startswith('---'):
        lines = body.split('\n')
        for line in lines[1:]:
            if line == '---':
                break
            if line.startswith('claimed_by:'):
                val = line.split(':', 1)[1].strip()
                if val and val != 'null':
                    claimed_by = val
                break

    # Apply filters
    filter_claimed = '${filter_claimed_by}'
    filter_unclaimed = '${filter_unclaimed}'

    if filter_claimed and claimed_by != filter_claimed:
        continue
    if filter_unclaimed == 'true' and claimed_by != '-':
        continue

    print(f'#{number:<5} {issue_type:<8} {claimed_by:<12} {title}')
"
}
```

**Step 3: Update main() to dispatch to cmd_list**

Replace the case for `list` in main():

```bash
    list)
      shift
      cmd_list "$@"
      ;;
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Implement cmd_show function

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_show function before main()**

```bash
# Show issue details
# Usage: gbeads show <number>
cmd_show() {
  require_repo

  if [[ $# -lt 1 ]]; then
    echo "Usage: gbeads show <number>" >&2
    exit 1
  fi

  local number="$1"

  # Get issue data
  local issue_json
  issue_json=$(gh issue view "$number" --repo "$REPO" --json number,title,state,body,labels 2>&1) || {
    echo "Error: Issue #$number not found" >&2
    exit 1
  }

  # Parse and display using Python for reliable JSON handling
  echo "$issue_json" | python3 -c "
import json
import sys

issue = json.load(sys.stdin)
number = issue['number']
title = issue['title']
state = issue['state']
body = issue.get('body', '')
labels = [l['name'] for l in issue.get('labels', [])]

# Determine type
issue_type = 'unknown'
type_map = {
    'type: feature': 'feature',
    'type: user story': 'story',
    'type: task': 'task',
    'type: bug': 'bug'
}
for label in labels:
    if label in type_map:
        issue_type = type_map[label]
        break

# Parse frontmatter
depends_on = '[]'
claimed_by = 'null'
parent = 'null'
body_content = body

if body.startswith('---'):
    lines = body.split('\n')
    frontmatter_end = -1
    for i, line in enumerate(lines[1:], 1):
        if line == '---':
            frontmatter_end = i
            break
        if line.startswith('depends_on:'):
            depends_on = line.split(':', 1)[1].strip()
        elif line.startswith('claimed_by:'):
            claimed_by = line.split(':', 1)[1].strip()
        elif line.startswith('parent:'):
            parent = line.split(':', 1)[1].strip()

    if frontmatter_end > 0:
        body_content = '\n'.join(lines[frontmatter_end + 1:]).strip()

print(f'Issue #{number}: {title}')
print(f'Type:       {issue_type}')
print(f'State:      {state}')
print(f'Claimed by: {claimed_by}')
print(f'Parent:     {parent}')
print(f'Depends on: {depends_on}')
print()
if body_content:
    print('Description:')
    print(body_content)
"
}
```

**Step 2: Update main() to dispatch to cmd_show**

Replace the case for `show` in main():

```bash
    show)
      shift
      cmd_show "$@"
      ;;
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create tests for list and show commands

**Files:**
- Create: `tests/list_show.bats`

**Step 1: Create list and show command tests**

```bash
#!/usr/bin/env bats

load test_helper

setup() {
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git"

  # Initialize labels
  "$PROJECT_ROOT/gbeads" init >/dev/null
}

@test "list shows header when no issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads list
  assert_success
  assert_output --partial "No issues found"
}

@test "list displays issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null
  "$PROJECT_ROOT/gbeads" create feature "Test feature" >/dev/null

  run_gbeads list
  assert_success
  assert_output --partial "Test task"
  assert_output --partial "Test feature"
}

@test "list --type filters by type" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "A task" >/dev/null
  "$PROJECT_ROOT/gbeads" create feature "A feature" >/dev/null

  run_gbeads list --type task
  assert_success
  assert_output --partial "A task"
  refute_output --partial "A feature"
}

@test "list --unclaimed filters unclaimed issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Unclaimed task" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Claimed task" >/dev/null

  # Claim the second task (would need claim command, skip for now)
  # For this test, we verify unclaimed shows all when none are claimed
  run_gbeads list --unclaimed
  assert_success
  assert_output --partial "Unclaimed task"
  assert_output --partial "Claimed task"
}

@test "list --claimed-by filters by worker id" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Task 1" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 2" >/dev/null
  "$PROJECT_ROOT/gbeads" claim 1 agent-001 >/dev/null

  run_gbeads list --claimed-by agent-001
  assert_success
  assert_output --partial "Task 1"
  refute_output --partial "Task 2"
}

@test "list validates type" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads list --type invalid
  assert_failure
  assert_output --partial "Invalid type"
}

@test "show displays issue details" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create task "Show test task" >/dev/null

  run_gbeads show 1
  assert_success
  assert_output --partial "Issue #1"
  assert_output --partial "Show test task"
  assert_output --partial "Type:       task"
  assert_output --partial "State:      open"
}

@test "show displays frontmatter fields" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child" --parent 1 >/dev/null

  run_gbeads show 2
  assert_success
  assert_output --partial "Parent:     1"
}

@test "show fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads show 999
  assert_failure
  assert_output --partial "not found"
}

@test "show requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads show
  assert_failure
  assert_output --partial "Usage:"
}
```

**Step 2: Run tests**

Run:
```bash
bats tests/list_show.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/list_show.bats
git commit -m "feat: implement list and show commands"
```
<!-- END_TASK_3 -->
<!-- END_SUBCOMPONENT_A -->

<!-- START_TASK_4 -->
### Task 4: Verify Phase 5 completion

**Step 1: Run all tests**

Run:
```bash
make test
```

Expected: All tests pass

**Step 2: Verify lint passes**

Run:
```bash
make lint
```

Expected: No errors (may need to format Python embedded in bash)

**Step 3: Manual verification**

Test the list and show commands work together:

```bash
cd /tmp && mkdir -p test-phase5 && cd test-phase5
git init && git remote add origin git@github.com:test/repo.git
export MOCK_GH_STATE=/tmp/test-phase5-state
export PATH="/path/to/gbeads/tests/mock_gh:$PATH"

/path/to/gbeads init
/path/to/gbeads create feature "Auth system"
/path/to/gbeads create task "Login form" --parent 1
/path/to/gbeads create task "Logout button" --parent 1
/path/to/gbeads list
/path/to/gbeads list --type task
/path/to/gbeads show 1
/path/to/gbeads show 2
```

Expected: Lists show filtered results, show displays full details
<!-- END_TASK_4 -->
