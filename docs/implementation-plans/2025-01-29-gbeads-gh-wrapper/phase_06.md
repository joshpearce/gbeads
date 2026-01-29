# gbeads Implementation Plan - Phase 6: Claim and Lifecycle Commands

**Goal:** Worker claiming and issue state management

**Architecture:** Add cmd_claim, cmd_unclaim, cmd_close, cmd_reopen functions

**Tech Stack:** Bash, gh CLI

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - Phase 5 commands expected to exist

---

<!-- START_SUBCOMPONENT_A (tasks 1-3) -->
<!-- START_TASK_1 -->
### Task 1: Implement cmd_claim and cmd_unclaim functions

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_claim function before main()**

```bash
# Claim an issue for a worker
# Usage: gbeads claim <number> <worker-id>
cmd_claim() {
  require_repo

  if [[ $# -lt 2 ]]; then
    echo "Usage: gbeads claim <number> <worker-id>" >&2
    exit 1
  fi

  local number="$1"
  local worker_id="$2"

  # Get current issue body
  local body
  body=$(gh issue view "$number" --repo "$REPO" --json body --jq '.body' 2>&1) || {
    echo "Error: Issue #$number not found" >&2
    exit 1
  }

  # Check if already claimed
  local current_claimed
  current_claimed=$(parse_frontmatter_field "$body" "claimed_by")
  if [[ -n "$current_claimed" && "$current_claimed" != "null" ]]; then
    echo "Error: Issue #$number is already claimed by $current_claimed" >&2
    exit 1
  fi

  # Update claimed_by in frontmatter
  local updated_body
  updated_body=$(update_frontmatter_field "$body" "claimed_by" "$worker_id")

  # Save updated body
  gh issue edit "$number" --repo "$REPO" --body "$updated_body"

  echo "Claimed issue #$number for $worker_id"
}
```

**Step 2: Add cmd_unclaim function**

```bash
# Release a claimed issue
# Usage: gbeads unclaim <number>
cmd_unclaim() {
  require_repo

  if [[ $# -lt 1 ]]; then
    echo "Usage: gbeads unclaim <number>" >&2
    exit 1
  fi

  local number="$1"

  # Get current issue body
  local body
  body=$(gh issue view "$number" --repo "$REPO" --json body --jq '.body' 2>&1) || {
    echo "Error: Issue #$number not found" >&2
    exit 1
  }

  # Check if actually claimed
  local current_claimed
  current_claimed=$(parse_frontmatter_field "$body" "claimed_by")
  if [[ -z "$current_claimed" || "$current_claimed" == "null" ]]; then
    echo "Issue #$number is not claimed" >&2
    exit 0
  fi

  # Update claimed_by to null
  local updated_body
  updated_body=$(update_frontmatter_field "$body" "claimed_by" "null")

  # Save updated body
  gh issue edit "$number" --repo "$REPO" --body "$updated_body"

  echo "Released claim on issue #$number (was: $current_claimed)"
}
```

**Step 3: Update main() to dispatch to claim/unclaim**

Replace the cases for `claim` and `unclaim` in main():

```bash
    claim)
      shift
      cmd_claim "$@"
      ;;
    unclaim)
      shift
      cmd_unclaim "$@"
      ;;
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Implement cmd_close and cmd_reopen functions

**Files:**
- Modify: `gbeads`

**Step 1: Add cmd_close function before main()**

```bash
# Close an issue
# Usage: gbeads close <number>
cmd_close() {
  require_repo

  if [[ $# -lt 1 ]]; then
    echo "Usage: gbeads close <number>" >&2
    exit 1
  fi

  local number="$1"

  gh issue close "$number" --repo "$REPO" || {
    echo "Error: Failed to close issue #$number" >&2
    exit 1
  }

  echo "Closed issue #$number"
}
```

**Step 2: Add cmd_reopen function**

```bash
# Reopen a closed issue
# Usage: gbeads reopen <number>
cmd_reopen() {
  require_repo

  if [[ $# -lt 1 ]]; then
    echo "Usage: gbeads reopen <number>" >&2
    exit 1
  fi

  local number="$1"

  gh issue reopen "$number" --repo "$REPO" || {
    echo "Error: Failed to reopen issue #$number" >&2
    exit 1
  }

  echo "Reopened issue #$number"
}
```

**Step 3: Update main() to dispatch to close/reopen**

Replace the cases for `close` and `reopen` in main():

```bash
    close)
      shift
      cmd_close "$@"
      ;;
    reopen)
      shift
      cmd_reopen "$@"
      ;;
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create tests for claim, unclaim, close, reopen

**Files:**
- Create: `tests/lifecycle.bats`

**Step 1: Create lifecycle command tests**

```bash
#!/usr/bin/env bats

load test_helper

# Clean test state at start of file (persists for inspection after tests)
setup_file() {
  rm -rf "$TEST_DIR/test_data"
  mkdir -p "$TEST_DIR/test_data"
}

setup() {
  mkdir -p "$MOCK_GH_STATE/mock_repo"
  cd "$MOCK_GH_STATE/mock_repo"
  git init -q
  git remote add origin "git@github.com:test/repo.git"

  # Initialize labels and create a test issue
  "$PROJECT_ROOT/gbeads" init >/dev/null
  "$PROJECT_ROOT/gbeads" create task "Test task" >/dev/null
}

# Claim tests

@test "claim requires number and worker-id" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads claim
  assert_failure
  assert_output --partial "Usage:"

  run_gbeads claim 1
  assert_failure
  assert_output --partial "Usage:"
}

@test "claim sets claimed_by in frontmatter" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads claim 1 agent-001
  assert_success
  assert_output --partial "Claimed issue #1 for agent-001"

  run gh issue view 1 --json body
  assert_output --partial "claimed_by: agent-001"
}

@test "claim fails if already claimed" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" claim 1 agent-001 >/dev/null

  run_gbeads claim 1 agent-002
  assert_failure
  assert_output --partial "already claimed"
}

@test "claim fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads claim 999 agent-001
  assert_failure
  assert_output --partial "not found"
}

# Unclaim tests

@test "unclaim requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads unclaim
  assert_failure
  assert_output --partial "Usage:"
}

@test "unclaim clears claimed_by" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" claim 1 agent-001 >/dev/null

  run_gbeads unclaim 1
  assert_success
  assert_output --partial "Released claim"

  run gh issue view 1 --json body
  assert_output --partial "claimed_by: null"
}

@test "unclaim on unclaimed issue is idempotent" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads unclaim 1
  assert_success
  assert_output --partial "not claimed"
}

# Close tests

@test "close requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads close
  assert_failure
  assert_output --partial "Usage:"
}

@test "close closes the issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads close 1
  assert_success
  assert_output --partial "Closed issue #1"

  run gh issue view 1 --json state
  assert_output --partial "closed"
}

@test "close fails for nonexistent issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads close 999
  assert_failure
}

# Reopen tests

@test "reopen requires issue number" {
  cd "$MOCK_GH_STATE/mock_repo"
  run_gbeads reopen
  assert_failure
  assert_output --partial "Usage:"
}

@test "reopen reopens closed issue" {
  cd "$MOCK_GH_STATE/mock_repo"
  "$PROJECT_ROOT/gbeads" close 1 >/dev/null

  run_gbeads reopen 1
  assert_success
  assert_output --partial "Reopened issue #1"

  run gh issue view 1 --json state
  assert_output --partial "open"
}

# Integration test

@test "full claim lifecycle works" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Claim
  run_gbeads claim 1 worker-123
  assert_success

  # Verify claimed in show
  run_gbeads show 1
  assert_output --partial "Claimed by: worker-123"

  # Unclaim
  run_gbeads unclaim 1
  assert_success

  # Verify unclaimed
  run_gbeads show 1
  assert_output --partial "Claimed by: null"
}

@test "full close/reopen lifecycle works" {
  cd "$MOCK_GH_STATE/mock_repo"

  # Close
  run_gbeads close 1
  assert_success

  # Verify closed
  run_gbeads show 1
  assert_output --partial "State:      closed"

  # Reopen
  run_gbeads reopen 1
  assert_success

  # Verify open
  run_gbeads show 1
  assert_output --partial "State:      open"
}
```

**Step 2: Run tests**

Run:
```bash
bats tests/lifecycle.bats
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add gbeads tests/lifecycle.bats
git commit -m "feat: implement claim, unclaim, close, reopen commands"
```
<!-- END_TASK_3 -->
<!-- END_SUBCOMPONENT_A -->

<!-- START_TASK_4 -->
### Task 4: Verify Phase 6 completion

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

**Step 3: Verify claim filtering in list**

Now that claim works, verify list --claimed-by and --unclaimed filters work.

Run (from the gbeads project root):
```bash
cd /tmp && rm -rf test-phase6 && mkdir test-phase6 && cd test-phase6
git init && git remote add origin git@github.com:test/repo.git
export MOCK_GH_STATE=/tmp/test-phase6-state
export PROJECT_ROOT="<absolute-path-to-gbeads-repo>"
export PATH="$PROJECT_ROOT/tests/mock_gh:$PATH"

$PROJECT_ROOT/gbeads init
$PROJECT_ROOT/gbeads create task "Task 1"
$PROJECT_ROOT/gbeads create task "Task 2"
$PROJECT_ROOT/gbeads claim 1 agent-001

$PROJECT_ROOT/gbeads list
$PROJECT_ROOT/gbeads list --unclaimed
$PROJECT_ROOT/gbeads list --claimed-by agent-001
```

Note: Replace `<absolute-path-to-gbeads-repo>` with the actual absolute path to the gbeads repository (e.g., `/Users/josh/code/gbeads`).

Expected: Filters work correctly
<!-- END_TASK_4 -->
