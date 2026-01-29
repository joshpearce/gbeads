# gbeads Implementation Plan - Phase 8: Children Command and Documentation

**Goal:** Manage task lists and complete documentation

**Architecture:** Add cmd_children function and create docs/usage.md

**Tech Stack:** Bash, gh CLI, Markdown

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - Phase 7 commands expected to exist

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->
<!-- START_TASK_1 -->
### Task 1: Implement cmd_children function

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_children function before main()**

```bash
# Manage child issues in task list
# Usage: gbeads children <number> [--add <n,...>] [--remove <n>]
cmd_children() {
  require_repo

  if [[ $# -lt 1 ]]; then
    echo "Usage: gbeads children <number> [--add <n,...>] [--remove <n>]" >&2
    exit 1
  fi

  local number="$1"
  shift

  local add_children=""
  local remove_child=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --add)
        add_children="$2"
        shift 2
        ;;
      --remove)
        remove_child="$2"
        shift 2
        ;;
      *)
        echo "Error: Unknown option '$1'" >&2
        exit 1
        ;;
    esac
  done

  # Get current issue body
  local body
  body=$(gh issue view "$number" --repo "$REPO" --json body --jq '.body' 2>&1) || {
    echo "Error: Issue #$number not found" >&2
    exit 1
  }

  # If no flags, list children
  if [[ -z "$add_children" && -z "$remove_child" ]]; then
    list_children "$body"
    return 0
  fi

  local updated_body="$body"

  # Handle add
  if [[ -n "$add_children" ]]; then
    # Split by comma
    IFS=',' read -ra child_numbers <<< "$add_children"
    for child_num in "${child_numbers[@]}"; do
      child_num=$(echo "$child_num" | tr -d ' ')

      # Get child's title
      local child_title
      child_title=$(gh issue view "$child_num" --repo "$REPO" --json title --jq '.title' 2>&1) || {
        echo "Warning: Issue #$child_num not found, skipping" >&2
        continue
      }

      # Update child's frontmatter to set parent
      local child_body
      child_body=$(gh issue view "$child_num" --repo "$REPO" --json body --jq '.body')
      local updated_child_body
      updated_child_body=$(update_frontmatter_field "$child_body" "parent" "$number")
      gh issue edit "$child_num" --repo "$REPO" --body "$updated_child_body"

      # Add to task list
      updated_body=$(add_task_list_entry "$updated_body" "$child_num" "$child_title")
      echo "Added #$child_num: $child_title"
    done
  fi

  # Handle remove
  if [[ -n "$remove_child" ]]; then
    # Clear parent in child's frontmatter
    local child_body
    child_body=$(gh issue view "$remove_child" --repo "$REPO" --json body --jq '.body' 2>/dev/null)
    if [[ -n "$child_body" ]]; then
      local updated_child_body
      updated_child_body=$(update_frontmatter_field "$child_body" "parent" "null")
      gh issue edit "$remove_child" --repo "$REPO" --body "$updated_child_body"
    fi

    # Remove from task list
    updated_body=$(remove_task_list_entry "$updated_body" "$remove_child")
    echo "Removed #$remove_child from task list"
  fi

  # Save updated parent body
  gh issue edit "$number" --repo "$REPO" --body "$updated_body"
}

# List children from task list
list_children() {
  local body="$1"

  local entries
  entries=$(parse_task_list "$body")

  if [[ -z "$entries" ]]; then
    echo "No children in task list."
    return 0
  fi

  echo "Children:"
  echo "$entries" | while IFS='|' read -r num title checked; do
    local status="[ ]"
    [[ "$checked" == "true" ]] && status="[x]"
    printf "  %s #%-4s %s\n" "$status" "$num" "$title"
  done
}
```

**Step 2: Update main() to dispatch to children**

Replace the case for `children` in main():

```bash
    children)
      shift
      cmd_children "$@"
      ;;
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create tests for children command

**Files:**
- Create: `tests/children.bats`

**Step 1: Create children command tests**

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

@test "children requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads children
  assert_failure
  assert_output --partial "Usage:"
}

@test "children with no flags lists children" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child 1" --parent 1 >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child 2" --parent 1 >/dev/null

  run_gbeads children 1
  assert_success
  assert_output --partial "Children:"
  assert_output --partial "#2"
  assert_output --partial "Child 1"
  assert_output --partial "#3"
  assert_output --partial "Child 2"
}

@test "children shows empty message when no children" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Standalone" >/dev/null

  run_gbeads children 1
  assert_success
  assert_output --partial "No children"
}

@test "children --add adds child to task list" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Orphan task" >/dev/null

  run_gbeads children 1 --add 2
  assert_success
  assert_output --partial "Added #2"

  # Verify parent has child in task list
  run gh issue view 1 --json body
  assert_output --partial "- [ ] #2 Orphan task"

  # Verify child has parent in frontmatter
  run gh issue view 2 --json body
  assert_output --partial "parent: 1"
}

@test "children --add handles multiple children" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 1" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 2" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Task 3" >/dev/null

  run_gbeads children 1 --add "2,3,4"
  assert_success
  assert_output --partial "Added #2"
  assert_output --partial "Added #3"
  assert_output --partial "Added #4"

  run_gbeads children 1
  assert_output --partial "#2"
  assert_output --partial "#3"
  assert_output --partial "#4"
}

@test "children --remove removes child from task list" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Child" --parent 1 >/dev/null

  run_gbeads children 1 --remove 2
  assert_success
  assert_output --partial "Removed #2"

  # Verify child is not in parent's task list
  run gh issue view 1 --json body
  refute_output --partial "#2"

  # Verify child's parent is cleared
  run gh issue view 2 --json body
  assert_output --partial "parent: null"
}

@test "children --add skips nonexistent issues" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" create feature "Parent" >/dev/null

  run_gbeads children 1 --add 999
  assert_success
  assert_output --partial "not found"
}

@test "children fails for nonexistent parent" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads children 999
  assert_failure
  assert_output --partial "not found"
}
```

**Step 2: Run tests**

Run:
```bash
bats tests/children.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/children.bats
git commit -m "feat: implement children command for task list management"
```
<!-- END_TASK_2 -->
<!-- END_SUBCOMPONENT_A -->

<!-- START_TASK_3 -->
### Task 3: Create docs/usage.md

**Files:**
- Create: `docs/usage.md`

**Step 1: Create full command reference**

```markdown
# gbeads Command Reference

gbeads is a lightweight wrapper around the GitHub CLI (`gh`) that provides work organization primitives using GitHub issues.

## Prerequisites

- [GitHub CLI (gh)](https://cli.github.com/) installed and authenticated
- Bash 4.0+
- Python 3 (for JSON processing)

## Core Concepts

### Issue Types

gbeads supports four issue types, managed via GitHub labels:

| Type | Label | Usage |
|------|-------|-------|
| feature | `type: feature` | High-level features or epics |
| story | `type: user story` | User-facing stories |
| task | `type: task` | Implementation tasks |
| bug | `type: bug` | Bug reports |

### Frontmatter

Each issue body contains YAML frontmatter with metadata:

```yaml
---
depends_on: []
claimed_by: null
parent: null
---
```

- `depends_on`: Array of issue numbers this issue depends on
- `claimed_by`: Worker identifier (for agent coordination)
- `parent`: Parent issue number (for hierarchical relationships)

### Task Lists

Parent issues contain GitHub task lists linking to children:

```markdown
## Tasks
- [ ] #12 Implement login form
- [x] #13 Add validation
- [ ] #14 Style form
```

## Commands

### init

Initialize gbeads labels in the current repository.

```bash
gbeads init
```

Creates the four type labels if they don't exist.

### create

Create a new typed issue.

```bash
gbeads create <type> "title" [--parent <n>]
```

**Arguments:**
- `type`: One of `feature`, `story`, `task`, `bug`
- `title`: Issue title (quoted)

**Options:**
- `--parent <n>`: Set parent issue and add to parent's task list

**Examples:**

```bash
gbeads create feature "User authentication"
gbeads create story "Login flow" --parent 1
gbeads create task "Build form" --parent 2
gbeads create bug "Login fails on mobile"
```

### list

List issues with optional filters.

```bash
gbeads list [--type <type>] [--claimed-by <id>] [--unclaimed] [--state <state>] [--all]
```

**Options:**
- `--type <type>`: Filter by issue type
- `--claimed-by <id>`: Filter by worker ID
- `--unclaimed`: Show only unclaimed issues
- `--state <state>`: Filter by state (`open`, `closed`)
- `--all`: Show all issues regardless of state

**Examples:**

```bash
gbeads list                        # All open issues
gbeads list --type task            # Open tasks only
gbeads list --unclaimed            # Available work
gbeads list --claimed-by agent-001 # Agent's current work
gbeads list --all                  # Include closed issues
```

### show

Display issue details.

```bash
gbeads show <number>
```

Shows issue title, type, state, and parsed frontmatter fields.

**Example:**

```bash
gbeads show 5
```

Output:
```
Issue #5: Implement login form
Type:       task
State:      open
Claimed by: agent-001
Parent:     2
Depends on: []

Description:
Form implementation details...
```

### claim

Claim an issue for a worker.

```bash
gbeads claim <number> <worker-id>
```

Sets `claimed_by` in frontmatter. Fails if already claimed.

**Example:**

```bash
gbeads claim 5 agent-001
```

### unclaim

Release a claimed issue.

```bash
gbeads unclaim <number>
```

Clears `claimed_by` in frontmatter.

**Example:**

```bash
gbeads unclaim 5
```

### update

Update issue title or type.

```bash
gbeads update <number> [--title "new title"] [--type <type>]
```

**Options:**
- `--title "..."`: Update issue title (syncs to parent task list)
- `--type <type>`: Change issue type (swaps labels)

**Examples:**

```bash
gbeads update 5 --title "Build login form component"
gbeads update 5 --type bug
gbeads update 5 --title "New name" --type feature
```

### close

Close an issue.

```bash
gbeads close <number>
```

**Example:**

```bash
gbeads close 5
```

### reopen

Reopen a closed issue.

```bash
gbeads reopen <number>
```

**Example:**

```bash
gbeads reopen 5
```

### children

Manage child issues in a parent's task list.

```bash
gbeads children <number> [--add <n,...>] [--remove <n>]
```

**Without flags:** Lists current children

**Options:**
- `--add <n,...>`: Add issues to task list (comma-separated)
- `--remove <n>`: Remove issue from task list

Adding a child:
1. Sets `parent` in child's frontmatter
2. Adds task list entry to parent

Removing a child:
1. Clears `parent` in child's frontmatter
2. Removes task list entry from parent

**Examples:**

```bash
gbeads children 1                  # List children of #1
gbeads children 1 --add 5,6,7      # Add #5, #6, #7 as children
gbeads children 1 --remove 5       # Remove #5 from children
```

## Workflows

### Basic Work Management

```bash
# Initialize repository
gbeads init

# Create feature with tasks
gbeads create feature "User Profile"
gbeads create task "Add profile page" --parent 1
gbeads create task "Add edit form" --parent 1
gbeads create task "Add avatar upload" --parent 1

# List available work
gbeads list --type task --unclaimed

# Claim and work on a task
gbeads claim 2 my-id
gbeads show 2

# Complete work
gbeads close 2

# Check progress
gbeads children 1
```

### Agent Coordination

```bash
# Agent claims available work
gbeads list --type task --unclaimed
gbeads claim 5 agent-$(hostname)

# Agent completes work
gbeads close 5
gbeads unclaim 5  # Optional if closing

# Find next task
gbeads list --type task --unclaimed
```

## Error Handling

- All commands require being in a git repository with a GitHub remote
- Invalid types show list of valid types
- Missing issues return clear error messages
- Claiming already-claimed issues fails with current owner shown
```

**Step 2: Commit**

```bash
git add docs/usage.md
git commit -m "docs: add complete command reference"
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Run all integration tests

**Files:**
- Create: `tests/integration.bats`

**Step 1: Create comprehensive integration test**

```bash
#!/usr/bin/env bats

load test_helper

setup() {
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git"
}

@test "full workflow: init, create hierarchy, claim, update, close" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Initialize
  run_gbeads init
  assert_success

  # Create feature with stories and tasks
  run_gbeads create feature "User Authentication"
  assert_success

  run_gbeads create story "Login Flow" --parent 1
  assert_success

  run_gbeads create task "Build form" --parent 2
  assert_success

  run_gbeads create task "Add validation" --parent 2
  assert_success

  # Verify hierarchy
  run_gbeads children 1
  assert_output --partial "#2"

  run_gbeads children 2
  assert_output --partial "#3"
  assert_output --partial "#4"

  # Claim a task
  run_gbeads claim 3 worker-001
  assert_success

  # List unclaimed tasks
  run_gbeads list --type task --unclaimed
  assert_success
  assert_output --partial "#4"
  refute_output --partial "#3"

  # Update task title (should sync to parent)
  run_gbeads update 3 --title "Build login form"
  assert_success

  run_gbeads children 2
  assert_output --partial "Build login form"

  # Complete task
  run_gbeads close 3
  assert_success

  # Verify state
  run_gbeads show 3
  assert_output --partial "State:      closed"

  # Reopen if needed
  run_gbeads reopen 3
  assert_success

  run_gbeads show 3
  assert_output --partial "State:      open"
}

@test "children management: add orphans, remove children" {
  cd "$MOCK_GH_STATE/mock_repo"

  run_gbeads init
  assert_success

  # Create parent and orphan tasks
  run_gbeads create feature "Epic"
  run_gbeads create task "Orphan 1"
  run_gbeads create task "Orphan 2"
  assert_success

  # Add orphans as children
  run_gbeads children 1 --add "2,3"
  assert_success

  run_gbeads children 1
  assert_output --partial "#2"
  assert_output --partial "#3"

  # Verify children have parent set
  run_gbeads show 2
  assert_output --partial "Parent:     1"

  # Remove a child
  run_gbeads children 1 --remove 2
  assert_success

  run_gbeads children 1
  refute_output --partial "#2"
  assert_output --partial "#3"

  # Verify removed child has no parent
  run_gbeads show 2
  assert_output --partial "Parent:     null"
}
```

**Step 2: Run all tests**

Run:
```bash
make test
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add tests/integration.bats
git commit -m "test: add full integration tests"
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Verify Phase 8 completion and final checks

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

**Step 3: Verify pre-commit passes**

Run:
```bash
pre-commit run --all-files
```

Expected: All hooks pass

**Step 4: Review Definition of Done**

Verify each item from the design plan:

- [x] `gbeads` executable script exists in repo root
- [x] `gbeads init` creates four type labels
- [x] `gbeads create <type> "title"` creates issues with correct label and YAML frontmatter
- [x] `gbeads list` filters by type, claimed_by, and unclaimed status
- [x] `gbeads show <number>` displays issue details
- [x] `gbeads claim/unclaim` manages worker field in frontmatter
- [x] `gbeads update` modifies title/type and syncs parent task list
- [x] `gbeads close/reopen` manages issue state
- [x] `gbeads children` manages parent/child relationships via task lists
- [x] All commands enforce current-repo scope
- [x] Python mock `gh` enables stateful testing
- [x] All tests pass via `bats tests/`
- [x] Pre-commit hooks (shellcheck, shfmt) configured and passing
- [x] README with installation and usage instructions

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: complete gbeads implementation"
```
<!-- END_TASK_5 -->
