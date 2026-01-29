# gbeads Implementation Plan - Phase 4: Init and Create Commands

**Goal:** Initialize labels and create typed issues

**Architecture:** Add cmd_init and cmd_create functions that use gh CLI with --repo flag

**Tech Stack:** Bash, gh CLI

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - Phase 3 utilities expected to exist

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->
<!-- START_TASK_1 -->
### Task 1: Add type constants and validation

**Files:**
- Modify: `gbeads`

**Step 1: Add type constants after VERSION**

```bash
readonly VERSION="0.1.0"

# Valid issue types
readonly VALID_TYPES=("feature" "story" "task" "bug")

# Type to label mapping
declare -A TYPE_LABELS=(
  ["feature"]="type: feature"
  ["story"]="type: user story"
  ["task"]="type: task"
  ["bug"]="type: bug"
)
```

**Step 2: Add type validation function after require_repo**

```bash
# Validate issue type
# Usage: validate_type "type"
validate_type() {
  local type="$1"
  for valid in "${VALID_TYPES[@]}"; do
    if [[ "$type" == "$valid" ]]; then
      return 0
    fi
  done
  echo "Error: Invalid type '$type'" >&2
  echo "Valid types: ${VALID_TYPES[*]}" >&2
  return 1
}

# Get label for type
# Usage: get_type_label "type"
get_type_label() {
  local type="$1"
  echo "${TYPE_LABELS[$type]}"
}
```

**Step 3: Verify script still runs**

Run:
```bash
./gbeads --help
```

Expected: Help output displayed
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Implement cmd_init function

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_init function before main()**

```bash
# Initialize gbeads labels in the repository
cmd_init() {
  require_repo

  echo "Initializing gbeads labels in $REPO..."

  local created=0
  local exists=0

  for type in "${VALID_TYPES[@]}"; do
    local label="${TYPE_LABELS[$type]}"
    if gh label create "$label" --repo "$REPO" --description "gbeads: $type" 2>/dev/null; then
      echo "  Created: $label"
      ((created++))
    else
      echo "  Exists: $label"
      ((exists++))
    fi
  done

  echo "Done. Created $created labels, $exists already existed."
}
```

**Step 2: Update main() to dispatch to cmd_init**

Replace the case for `init` in main():

```bash
    init)
      shift
      cmd_init "$@"
      ;;
```

**Step 3: Verify init command works**

Run:
```bash
./gbeads init
```

Expected: Error about not being in a git repo (or creates labels if in a repo with GitHub remote)
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create tests for init command

**Files:**
- Create: `tests/init.bats`

**Step 1: Create init command tests**

```bash
#!/usr/bin/env bats

load test_helper

setup() {
  # Create a mock git repo for each test
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git"
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
```

**Step 2: Run tests**

Run:
```bash
bats tests/init.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/init.bats
git commit -m "feat: implement init command to create type labels"
```
<!-- END_TASK_3 -->
<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 4-6) -->
<!-- START_TASK_4 -->
### Task 4: Implement cmd_create function

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_create function before main()**

```bash
# Create a new issue
# Usage: gbeads create <type> "title" [--parent <n>]
cmd_create() {
  require_repo

  if [[ $# -lt 2 ]]; then
    echo "Usage: gbeads create <type> \"title\" [--parent <n>]" >&2
    exit 1
  fi

  local type="$1"
  local title="$2"
  shift 2

  # Validate type
  if ! validate_type "$type"; then
    exit 1
  fi

  # Parse optional flags
  local parent=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --parent)
        parent="$2"
        shift 2
        ;;
      *)
        echo "Error: Unknown option '$1'" >&2
        exit 1
        ;;
    esac
  done

  # Create frontmatter
  local body
  if [[ -n "$parent" ]]; then
    body=$(create_frontmatter "$parent")
  else
    body=$(create_frontmatter)
  fi

  # Get the label for this type
  local label
  label=$(get_type_label "$type")

  # Create the issue
  local output
  output=$(gh issue create --repo "$REPO" --title "$title" --body "$body" --label "$label")

  # Extract issue number from output URL
  local number
  number=$(echo "$output" | grep -o '[0-9]*$')

  echo "Created $type #$number: $title"

  # If parent specified, update parent's task list
  if [[ -n "$parent" ]]; then
    local parent_body
    parent_body=$(gh issue view "$parent" --repo "$REPO" --json body --jq '.body')

    local updated_body
    updated_body=$(add_task_list_entry "$parent_body" "$number" "$title")

    gh issue edit "$parent" --repo "$REPO" --body "$updated_body"
    echo "Added to parent #$parent task list"
  fi
}
```

**Step 2: Update main() to dispatch to cmd_create**

Replace the case for `create` in main():

```bash
    create)
      shift
      cmd_create "$@"
      ;;
```

**Step 3: Verify create command syntax**

Run:
```bash
./gbeads create
```

Expected: Usage error message
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Create tests for create command

**Files:**
- Create: `tests/create.bats`

**Step 1: Create create command tests**

```bash
#!/usr/bin/env bats

load test_helper

setup() {
  # Create a mock git repo for each test
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git"

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
```

**Step 2: Run tests**

Run:
```bash
bats tests/create.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/create.bats
git commit -m "feat: implement create command with parent support"
```
<!-- END_TASK_5 -->
<!-- END_SUBCOMPONENT_B -->

<!-- START_TASK_6 -->
### Task 6: Verify Phase 4 completion

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

**Step 3: Test manual workflow**

Run (from the gbeads project root):
```bash
cd /tmp
mkdir test-gbeads && cd test-gbeads
git init
git remote add origin git@github.com:test/repo.git
export MOCK_GH_STATE=/tmp/test-gbeads-state
export PROJECT_ROOT="<absolute-path-to-gbeads-repo>"
export PATH="$PROJECT_ROOT/tests/mock_gh:$PATH"

$PROJECT_ROOT/gbeads init
$PROJECT_ROOT/gbeads create feature "Auth system"
$PROJECT_ROOT/gbeads create task "Login form" --parent 1

gh issue list --json number,title,labels
gh issue view 1 --json body
```

Note: Replace `<absolute-path-to-gbeads-repo>` with the actual absolute path to the gbeads repository (e.g., `/Users/josh/code/gbeads`).

Expected: Labels created, issues created with correct structure
<!-- END_TASK_6 -->
