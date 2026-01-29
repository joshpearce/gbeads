# gbeads Implementation Plan - Phase 3: Core Utilities

**Goal:** Shared functions for repo validation and frontmatter handling

**Architecture:** Add utility functions to gbeads script for repo detection and YAML frontmatter manipulation

**Tech Stack:** Bash, sed, awk for text processing

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - Phase 2 infrastructure expected to exist

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->
<!-- START_TASK_1 -->
### Task 1: Add get_repo and require_repo functions

**Files:**
- Modify: `gbeads`

**Step 1: Add repo utility functions after the constants section**

Add after `readonly VERSION="0.1.0"`:

```bash
# Get the GitHub repo in owner/repo format from git remote
get_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null) || {
    echo ""
    return 1
  }

  # Handle SSH format: git@github.com:owner/repo.git
  if [[ "$remote_url" =~ git@github\.com:([^/]+)/(.+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    return 0
  fi

  # Handle HTTPS format: https://github.com/owner/repo.git
  if [[ "$remote_url" =~ https://github\.com/([^/]+)/(.+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    return 0
  fi

  echo ""
  return 1
}

# Require that we're in a git repo with a GitHub remote
# Sets REPO variable on success, exits on failure
require_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 1
  fi

  REPO=$(get_repo)
  if [[ -z "$REPO" ]]; then
    echo "Error: Could not determine GitHub repository from git remote" >&2
    echo "Make sure 'origin' points to a GitHub repository." >&2
    exit 1
  fi

  export REPO
}
```

**Step 2: Verify script still runs**

Run:
```bash
./gbeads --help
```

Expected: Help output displayed (no syntax errors)
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create tests for repo utilities

**Files:**
- Create: `tests/repo.bats`

**Step 1: Create repo utility tests**

```bash
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
  run bash -c "source $PROJECT_ROOT/gbeads; get_repo"
  assert_success
  assert_output "owner/repo"
}

@test "get_repo extracts owner/repo from HTTPS remote" {
  setup_mock_git_repo "https://github.com/owner/repo.git"
  run bash -c "source $PROJECT_ROOT/gbeads; get_repo"
  assert_success
  assert_output "owner/repo"
}

@test "get_repo handles remote without .git suffix" {
  setup_mock_git_repo "https://github.com/owner/repo"
  run bash -c "source $PROJECT_ROOT/gbeads; get_repo"
  assert_success
  assert_output "owner/repo"
}

@test "get_repo fails when not in git repo" {
  cd /tmp
  run bash -c "source $PROJECT_ROOT/gbeads; get_repo"
  assert_failure
}

@test "require_repo sets REPO variable" {
  setup_mock_git_repo "git@github.com:test/project.git"
  run bash -c "source $PROJECT_ROOT/gbeads; require_repo; echo \$REPO"
  assert_success
  assert_output "test/project"
}

@test "require_repo fails when not in git repo" {
  cd /tmp
  run bash -c "source $PROJECT_ROOT/gbeads; require_repo"
  assert_failure
  assert_output --partial "Not in a git repository"
}
```

**Step 2: Run tests**

Run:
```bash
bats tests/repo.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/repo.bats
git commit -m "feat: add get_repo and require_repo utility functions"
```
<!-- END_TASK_2 -->
<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 3-5) -->
<!-- START_TASK_3 -->
### Task 3: Add frontmatter utility functions

**Files:**
- Modify: `gbeads`

**Step 1: Add frontmatter functions after require_repo**

```bash
# Create initial frontmatter block
# Usage: create_frontmatter [parent]
create_frontmatter() {
  local parent="${1:-null}"
  cat <<EOF
---
depends_on: []
claimed_by: null
parent: $parent
---
EOF
}

# Parse frontmatter from issue body, returns the value of a field
# Usage: parse_frontmatter_field "body" "field_name"
parse_frontmatter_field() {
  local body="$1"
  local field="$2"

  # Check if body has frontmatter (starts with ---)
  if [[ ! "$body" =~ ^--- ]]; then
    echo ""
    return 0
  fi

  # Extract the frontmatter section
  local frontmatter
  frontmatter=$(echo "$body" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

  # Extract the field value
  echo "$frontmatter" | grep "^${field}:" | sed "s/^${field}: *//"
}

# Update a field in the frontmatter, returns the complete updated body
# Usage: update_frontmatter_field "body" "field_name" "new_value"
update_frontmatter_field() {
  local body="$1"
  local field="$2"
  local value="$3"

  # If no frontmatter exists, create it
  if [[ ! "$body" =~ ^--- ]]; then
    local frontmatter
    frontmatter=$(create_frontmatter)
    # Add body content after frontmatter
    body="${frontmatter}"$'\n'"${body}"
  fi

  # Replace the field value in frontmatter
  # This handles both "field: value" and "field: null" formats
  echo "$body" | sed "s/^${field}: .*/${field}: ${value}/"
}

# Extract body content after frontmatter
# Usage: get_body_content "full_body"
get_body_content() {
  local body="$1"

  # If no frontmatter, return as-is
  if [[ ! "$body" =~ ^--- ]]; then
    echo "$body"
    return 0
  fi

  # Skip the frontmatter section (between first and second ---)
  echo "$body" | sed '1,/^---$/d' | sed '1,/^---$/d'
}

# Check if issue body has a task list section
# Usage: has_task_list "body"
has_task_list() {
  local body="$1"
  [[ "$body" =~ "## Tasks" ]]
}

# Add a child to the task list in the body
# Usage: add_task_list_entry "body" "number" "title"
add_task_list_entry() {
  local body="$1"
  local number="$2"
  local title="$3"

  local entry="- [ ] #${number} ${title}"

  if has_task_list "$body"; then
    # Add after ## Tasks heading (POSIX-compatible approach)
    # Note: BSD sed (macOS) and GNU sed have different 'a' command syntax
    # Using awk for cross-platform compatibility
    echo "$body" | awk -v entry="$entry" '/^## Tasks$/{print; print entry; next}1'
  else
    # Add new ## Tasks section at end
    echo "$body"
    echo ""
    echo "## Tasks"
    echo "$entry"
  fi
}

# Remove a child from the task list
# Usage: remove_task_list_entry "body" "number"
remove_task_list_entry() {
  local body="$1"
  local number="$2"

  # Remove line matching "- [ ] #N " or "- [x] #N "
  echo "$body" | grep -v "^- \[[ x]\] #${number} "
}

# Update title in task list entry
# Usage: update_task_list_title "body" "number" "new_title"
update_task_list_title() {
  local body="$1"
  local number="$2"
  local new_title="$3"

  # Replace the title part after #N
  echo "$body" | sed "s/^\(- \[[ x]\] #${number}\) .*/\1 ${new_title}/"
}

# Parse task list entries from body
# Usage: parse_task_list "body"
# Output: "number|title|checked" per line
parse_task_list() {
  local body="$1"

  echo "$body" | grep "^- \[[ x]\] #[0-9]" | while read -r line; do
    local checked="false"
    if [[ "$line" =~ "- [x]" ]]; then
      checked="true"
    fi
    local number
    number=$(echo "$line" | sed 's/^- \[[ x]\] #\([0-9]*\).*/\1/')
    local title
    title=$(echo "$line" | sed 's/^- \[[ x]\] #[0-9]* //')
    echo "${number}|${title}|${checked}"
  done
}
```

**Step 2: Verify script still runs**

Run:
```bash
./gbeads --help
```

Expected: Help output displayed (no syntax errors)
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Create tests for frontmatter utilities

**Files:**
- Create: `tests/frontmatter.bats`

**Step 1: Create frontmatter utility tests**

```bash
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
```

**Step 2: Run tests**

Run:
```bash
bats tests/frontmatter.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/frontmatter.bats
git commit -m "feat: add frontmatter parsing utility functions"
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Create tests for task list utilities

**Files:**
- Create: `tests/tasklist.bats`

**Step 1: Create task list utility tests**

```bash
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
```

**Step 2: Run tests**

Run:
```bash
bats tests/tasklist.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add tests/tasklist.bats
git commit -m "feat: add task list management utility functions"
```
<!-- END_TASK_5 -->
<!-- END_SUBCOMPONENT_B -->

<!-- START_TASK_6 -->
### Task 6: Verify Phase 3 completion

**Step 1: Run all tests**

Run:
```bash
make test
```

Expected: All tests pass (smoke, repo, frontmatter, tasklist)

**Step 2: Verify lint passes**

Run:
```bash
make lint
```

Expected: No errors

**Step 3: Commit any lint fixes**

If lint made suggestions:

```bash
make format
git add gbeads
git commit -m "style: apply shfmt formatting"
```
<!-- END_TASK_6 -->
