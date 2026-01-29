# gbeads Implementation Plan - Phase 7: Update Command with Parent Sync

**Goal:** Modify issues and sync parent task lists

**Architecture:** Add cmd_update that handles --title and --type, syncing parent task list when title changes

**Tech Stack:** Bash, gh CLI

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - Phase 6 commands expected to exist

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->
<!-- START_TASK_1 -->
### Task 1: Implement cmd_update function

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_update function before main()**

```bash
# Update an issue
# Usage: gbeads update <number> [--title "new title"] [--type <type>]
cmd_update() {
  require_repo

  if [[ $# -lt 1 ]]; then
    echo "Usage: gbeads update <number> [--title \"new title\"] [--type <type>]" >&2
    exit 1
  fi

  local number="$1"
  shift

  local new_title=""
  local new_type=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title)
        new_title="$2"
        shift 2
        ;;
      --type)
        new_type="$2"
        if ! validate_type "$new_type"; then
          exit 1
        fi
        shift 2
        ;;
      *)
        echo "Error: Unknown option '$1'" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$new_title" && -z "$new_type" ]]; then
    echo "Error: Must specify --title or --type" >&2
    exit 1
  fi

  # Get current issue data
  local issue_json
  issue_json=$(gh issue view "$number" --repo "$REPO" --json title,body,labels 2>&1) || {
    echo "Error: Issue #$number not found" >&2
    exit 1
  }

  local current_title current_body current_labels
  current_title=$(echo "$issue_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])")
  current_body=$(echo "$issue_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('body',''))")
  current_labels=$(echo "$issue_json" | python3 -c "import json,sys; print(','.join([l['name'] for l in json.load(sys.stdin).get('labels',[])]))")

  # Handle title update
  if [[ -n "$new_title" ]]; then
    gh issue edit "$number" --repo "$REPO" --title "$new_title"
    echo "Updated title to: $new_title"

    # Sync parent task list if issue has a parent
    local parent
    parent=$(parse_frontmatter_field "$current_body" "parent")
    if [[ -n "$parent" && "$parent" != "null" ]]; then
      sync_parent_task_list "$parent" "$number" "$new_title"
    fi
  fi

  # Handle type update
  if [[ -n "$new_type" ]]; then
    local new_label
    new_label=$(get_type_label "$new_type")

    # Find and remove old type label
    for t in "${VALID_TYPES[@]}"; do
      local old_label="${TYPE_LABELS[$t]}"
      if [[ "$current_labels" == *"$old_label"* ]]; then
        gh issue edit "$number" --repo "$REPO" --remove-label "$old_label" 2>/dev/null || true
      fi
    done

    # Add new type label
    gh issue edit "$number" --repo "$REPO" --add-label "$new_label"
    echo "Updated type to: $new_type"
  fi
}

# Sync a child's title in the parent's task list
# Usage: sync_parent_task_list <parent_number> <child_number> <new_title>
sync_parent_task_list() {
  local parent_number="$1"
  local child_number="$2"
  local new_title="$3"

  # Get parent's body
  local parent_body
  parent_body=$(gh issue view "$parent_number" --repo "$REPO" --json body --jq '.body' 2>&1) || {
    echo "Warning: Could not find parent #$parent_number to sync task list" >&2
    return 0
  }

  # Update the task list entry
  local updated_body
  updated_body=$(update_task_list_title "$parent_body" "$child_number" "$new_title")

  # Save if changed
  if [[ "$updated_body" != "$parent_body" ]]; then
    gh issue edit "$parent_number" --repo "$REPO" --body "$updated_body"
    echo "Synced title to parent #$parent_number task list"
  fi
}
```

**Step 2: Update main() to dispatch to update**

Replace the case for `update` in main():

```bash
    update)
      shift
      cmd_update "$@"
      ;;
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create tests for update command

**Files:**
- Create: `tests/update.bats`

**Step 1: Create update command tests**

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
  assert_output --partial "Must specify --title or --type"
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
```

**Step 2: Run tests**

Run:
```bash
bats tests/update.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/update.bats
git commit -m "feat: implement update command with title and type support"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create tests for parent sync

**Files:**
- Modify: `tests/update.bats`

**Step 1: Add parent sync tests to update.bats**

```bash
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
```

**Step 2: Run tests**

Run:
```bash
bats tests/update.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add tests/update.bats
git commit -m "test: add parent task list sync tests for update command"
```
<!-- END_TASK_3 -->
<!-- END_SUBCOMPONENT_A -->

<!-- START_TASK_4 -->
### Task 4: Verify Phase 7 completion

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

Expected: No errors

**Step 3: Manual verification of parent sync**

Run (from the gbeads project root):
```bash
cd /tmp && rm -rf test-phase7 && mkdir test-phase7 && cd test-phase7
git init && git remote add origin git@github.com:test/repo.git
export MOCK_GH_STATE=/tmp/test-phase7-state
export PROJECT_ROOT="<absolute-path-to-gbeads-repo>"
export PATH="$PROJECT_ROOT/tests/mock_gh:$PATH"

$PROJECT_ROOT/gbeads init
$PROJECT_ROOT/gbeads create feature "Epic: User Auth"
$PROJECT_ROOT/gbeads create story "Login flow" --parent 1
$PROJECT_ROOT/gbeads create task "Build form" --parent 2

# Verify hierarchy
$PROJECT_ROOT/gbeads show 1  # Should show task list with #2
$PROJECT_ROOT/gbeads show 2  # Should show task list with #3, parent: 1

# Update child title
$PROJECT_ROOT/gbeads update 3 --title "Build login form"

# Verify parent updated
$PROJECT_ROOT/gbeads show 2  # Task list should show "Build login form"
```

Note: Replace `<absolute-path-to-gbeads-repo>` with the actual absolute path to the gbeads repository (e.g., `/Users/josh/code/gbeads`).

Expected: Title changes propagate to parent task lists
<!-- END_TASK_4 -->
