# gbeads Implementation Plan - Phase 2: Mock gh Infrastructure

**Goal:** Python mock `gh` that maintains state for testing

**Architecture:** Python script that emulates gh CLI subset, storing state as JSON in tests/test_data/

**Tech Stack:** Python 3, bats-core, bats-assert, bats-support

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - Phase 1 scaffolding expected to exist

---

<!-- START_TASK_1 -->
### Task 1: Create tests directory structure

**Files:**
- Create: `tests/mock_gh/` directory
- Create: `tests/fixtures/` directory

**Step 1: Create directory structure**

Run:
```bash
mkdir -p tests/mock_gh tests/fixtures
```

**Step 2: Verify**

Run:
```bash
ls -la tests/
```

Expected: Shows mock_gh/ and fixtures/ directories

**Step 3: Commit**

```bash
git add tests/
git commit -m "chore: create tests directory structure"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create Python mock gh script

**Files:**
- Create: `tests/mock_gh/gh`

**Step 1: Create the mock gh Python script**

```python
#!/usr/bin/env python3
"""
Mock gh CLI for testing gbeads.

Stores state in JSON files in the directory specified by MOCK_GH_STATE environment variable.
Supports a subset of gh commands needed for gbeads testing.
"""

import json
import os
import re
import sys
from pathlib import Path


def apply_jq_filter(data: any, jq_expr: str) -> any:
    """Apply a simple jq-like filter to data.

    Supports:
    - .field - extract field from object
    - .field1.field2 - nested field access
    - .[].field - extract field from each array element
    - .field[] - iterate over array field
    """
    if not jq_expr or jq_expr == ".":
        return data

    # Handle .field access
    if jq_expr.startswith("."):
        path = jq_expr[1:]  # Remove leading dot

        # Handle array iteration: .[].field or .field[]
        if "[]" in path:
            parts = path.split("[]", 1)
            before = parts[0]
            after = parts[1] if len(parts) > 1 else ""

            # Get the array
            if before:
                for key in before.rstrip(".").split("."):
                    if key:
                        data = data.get(key, {}) if isinstance(data, dict) else data

            # Iterate and extract
            if isinstance(data, list):
                results = []
                for item in data:
                    if after.startswith("."):
                        for key in after[1:].split("."):
                            if key:
                                item = item.get(key, "") if isinstance(item, dict) else item
                    results.append(item)
                return results
            return data

        # Simple field access: .field or .field.subfield
        for key in path.split("."):
            if key and isinstance(data, dict):
                data = data.get(key, "")
        return data

    return data


def format_jq_output(result: any) -> str:
    """Format jq result for output."""
    if isinstance(result, list):
        # For arrays of strings, output each on a line (like jq)
        if all(isinstance(x, str) for x in result):
            return "\n".join(result)
        return json.dumps(result)
    elif isinstance(result, str):
        return result
    else:
        return json.dumps(result)


def get_state_dir() -> Path:
    """Get the state directory from environment or default."""
    state_dir = os.environ.get("MOCK_GH_STATE", "tests/test_data")
    path = Path(state_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path


def load_issues() -> list:
    """Load issues from state file."""
    state_file = get_state_dir() / "issues.json"
    if state_file.exists():
        return json.loads(state_file.read_text())
    return []


def save_issues(issues: list) -> None:
    """Save issues to state file."""
    state_file = get_state_dir() / "issues.json"
    state_file.write_text(json.dumps(issues, indent=2))


def load_labels() -> list:
    """Load labels from state file."""
    state_file = get_state_dir() / "labels.json"
    if state_file.exists():
        return json.loads(state_file.read_text())
    return []


def save_labels(labels: list) -> None:
    """Save labels to state file."""
    state_file = get_state_dir() / "labels.json"
    state_file.write_text(json.dumps(labels, indent=2))


def cmd_label_create(args: list) -> int:
    """Handle: gh label create <name> [--description <desc>] [--color <color>]"""
    if not args:
        print("error: label name required", file=sys.stderr)
        return 1

    name = args[0]
    description = ""
    color = "ededed"

    i = 1
    while i < len(args):
        if args[i] in ("-d", "--description") and i + 1 < len(args):
            description = args[i + 1]
            i += 2
        elif args[i] in ("-c", "--color") and i + 1 < len(args):
            color = args[i + 1]
            i += 2
        elif args[i] in ("-R", "--repo"):
            # Ignore repo flag for mock
            i += 2
        else:
            i += 1

    labels = load_labels()

    # Check if label already exists
    for label in labels:
        if label["name"] == name:
            print(f"label already exists: {name}", file=sys.stderr)
            return 1

    labels.append({"name": name, "description": description, "color": color})
    save_labels(labels)
    print(f"Label created: {name}")
    return 0


def cmd_label_list(args: list) -> int:
    """Handle: gh label list [--json <fields>]"""
    labels = load_labels()
    json_fields = None

    i = 0
    while i < len(args):
        if args[i] == "--json" and i + 1 < len(args):
            json_fields = args[i + 1].split(",")
            i += 2
        elif args[i] in ("-R", "--repo"):
            i += 2
        else:
            i += 1

    if json_fields:
        output = []
        for label in labels:
            item = {}
            for field in json_fields:
                if field in label:
                    item[field] = label[field]
            output.append(item)
        print(json.dumps(output))
    else:
        for label in labels:
            print(f"{label['name']}\t{label['description']}")

    return 0


def cmd_issue_create(args: list) -> int:
    """Handle: gh issue create --title <t> --body <b> --label <l>"""
    title = ""
    body = ""
    labels = []

    i = 0
    while i < len(args):
        if args[i] in ("-t", "--title") and i + 1 < len(args):
            title = args[i + 1]
            i += 2
        elif args[i] in ("-b", "--body") and i + 1 < len(args):
            body = args[i + 1]
            i += 2
        elif args[i] in ("-l", "--label") and i + 1 < len(args):
            labels.append(args[i + 1])
            i += 2
        elif args[i] in ("-R", "--repo"):
            i += 2
        else:
            i += 1

    if not title:
        print("error: title required", file=sys.stderr)
        return 1

    issues = load_issues()
    number = len(issues) + 1

    issue = {
        "number": number,
        "title": title,
        "body": body,
        "labels": [{"name": l} for l in labels],
        "state": "open",
    }
    issues.append(issue)
    save_issues(issues)

    # gh issue create outputs the URL, we'll just output the number
    print(f"https://github.com/test/repo/issues/{number}")
    return 0


def cmd_issue_list(args: list) -> int:
    """Handle: gh issue list [--label <l>] [--state <s>] [--json <fields>] [--jq <expr>] [--limit <n>]"""
    issues = load_issues()
    filter_labels = []
    filter_state = "open"
    json_fields = None
    jq_expr = None
    limit = 100

    i = 0
    while i < len(args):
        if args[i] in ("-l", "--label") and i + 1 < len(args):
            filter_labels.append(args[i + 1])
            i += 2
        elif args[i] in ("-s", "--state") and i + 1 < len(args):
            filter_state = args[i + 1]
            i += 2
        elif args[i] == "--json" and i + 1 < len(args):
            json_fields = args[i + 1].split(",")
            i += 2
        elif args[i] in ("-q", "--jq") and i + 1 < len(args):
            jq_expr = args[i + 1]
            i += 2
        elif args[i] in ("-L", "--limit") and i + 1 < len(args):
            limit = int(args[i + 1])
            i += 2
        elif args[i] in ("-R", "--repo"):
            i += 2
        else:
            i += 1

    # Filter issues
    filtered = []
    for issue in issues:
        # State filter
        if filter_state != "all" and issue["state"] != filter_state:
            continue

        # Label filter (must have ALL specified labels)
        if filter_labels:
            issue_label_names = [l["name"] for l in issue.get("labels", [])]
            if not all(fl in issue_label_names for fl in filter_labels):
                continue

        filtered.append(issue)
        if len(filtered) >= limit:
            break

    if json_fields:
        output = []
        for issue in filtered:
            item = {}
            for field in json_fields:
                if field in issue:
                    item[field] = issue[field]
            output.append(item)
        # Apply jq filter if specified
        if jq_expr:
            result = apply_jq_filter(output, jq_expr)
            print(format_jq_output(result))
        else:
            print(json.dumps(output))
    else:
        for issue in filtered:
            labels_str = ", ".join(l["name"] for l in issue.get("labels", []))
            print(f"#{issue['number']}\t{issue['title']}\t{labels_str}")

    return 0


def cmd_issue_view(args: list) -> int:
    """Handle: gh issue view <number> [--json <fields>] [--jq <expr>]"""
    if not args:
        print("error: issue number required", file=sys.stderr)
        return 1

    try:
        number = int(args[0])
    except ValueError:
        print(f"error: invalid issue number: {args[0]}", file=sys.stderr)
        return 1

    json_fields = None
    jq_expr = None
    i = 1
    while i < len(args):
        if args[i] == "--json" and i + 1 < len(args):
            json_fields = args[i + 1].split(",")
            i += 2
        elif args[i] in ("-q", "--jq") and i + 1 < len(args):
            jq_expr = args[i + 1]
            i += 2
        elif args[i] in ("-R", "--repo"):
            i += 2
        else:
            i += 1

    issues = load_issues()
    issue = None
    for iss in issues:
        if iss["number"] == number:
            issue = iss
            break

    if not issue:
        print(f"issue {number} not found", file=sys.stderr)
        return 1

    if json_fields:
        output = {}
        for field in json_fields:
            if field in issue:
                output[field] = issue[field]
        # Apply jq filter if specified
        if jq_expr:
            result = apply_jq_filter(output, jq_expr)
            print(format_jq_output(result))
        else:
            print(json.dumps(output))
    else:
        print(f"#{issue['number']}: {issue['title']}")
        print(f"State: {issue['state']}")
        if issue.get("body"):
            print(f"\n{issue['body']}")

    return 0


def cmd_issue_edit(args: list) -> int:
    """Handle: gh issue edit <number> [--title <t>] [--body <b>] [--add-label <l>] [--remove-label <l>]"""
    if not args:
        print("error: issue number required", file=sys.stderr)
        return 1

    try:
        number = int(args[0])
    except ValueError:
        print(f"error: invalid issue number: {args[0]}", file=sys.stderr)
        return 1

    new_title = None
    new_body = None
    add_labels = []
    remove_labels = []

    i = 1
    while i < len(args):
        if args[i] in ("-t", "--title") and i + 1 < len(args):
            new_title = args[i + 1]
            i += 2
        elif args[i] in ("-b", "--body") and i + 1 < len(args):
            new_body = args[i + 1]
            i += 2
        elif args[i] == "--add-label" and i + 1 < len(args):
            add_labels.append(args[i + 1])
            i += 2
        elif args[i] == "--remove-label" and i + 1 < len(args):
            remove_labels.append(args[i + 1])
            i += 2
        elif args[i] in ("-R", "--repo"):
            i += 2
        else:
            i += 1

    issues = load_issues()
    found = False
    for issue in issues:
        if issue["number"] == number:
            if new_title is not None:
                issue["title"] = new_title
            if new_body is not None:
                issue["body"] = new_body
            # Handle label changes
            current_labels = [l["name"] for l in issue.get("labels", [])]
            for label in add_labels:
                if label not in current_labels:
                    current_labels.append(label)
            for label in remove_labels:
                if label in current_labels:
                    current_labels.remove(label)
            issue["labels"] = [{"name": l} for l in current_labels]
            found = True
            break

    if not found:
        print(f"issue {number} not found", file=sys.stderr)
        return 1

    save_issues(issues)
    print(f"Updated issue #{number}")
    return 0


def cmd_issue_close(args: list) -> int:
    """Handle: gh issue close <number>"""
    if not args:
        print("error: issue number required", file=sys.stderr)
        return 1

    try:
        number = int(args[0])
    except ValueError:
        print(f"error: invalid issue number: {args[0]}", file=sys.stderr)
        return 1

    issues = load_issues()
    found = False
    for issue in issues:
        if issue["number"] == number:
            issue["state"] = "closed"
            found = True
            break

    if not found:
        print(f"issue {number} not found", file=sys.stderr)
        return 1

    save_issues(issues)
    print(f"Closed issue #{number}")
    return 0


def cmd_issue_reopen(args: list) -> int:
    """Handle: gh issue reopen <number>"""
    if not args:
        print("error: issue number required", file=sys.stderr)
        return 1

    try:
        number = int(args[0])
    except ValueError:
        print(f"error: invalid issue number: {args[0]}", file=sys.stderr)
        return 1

    issues = load_issues()
    found = False
    for issue in issues:
        if issue["number"] == number:
            issue["state"] = "open"
            found = True
            break

    if not found:
        print(f"issue {number} not found", file=sys.stderr)
        return 1

    save_issues(issues)
    print(f"Reopened issue #{number}")
    return 0


def main() -> int:
    args = sys.argv[1:]

    if not args:
        print("error: command required", file=sys.stderr)
        return 1

    cmd = args[0]
    rest = args[1:]

    if cmd == "label":
        if not rest:
            print("error: label subcommand required", file=sys.stderr)
            return 1
        subcmd = rest[0]
        if subcmd == "create":
            return cmd_label_create(rest[1:])
        elif subcmd == "list":
            return cmd_label_list(rest[1:])
        else:
            print(f"error: unknown label subcommand: {subcmd}", file=sys.stderr)
            return 1

    elif cmd == "issue":
        if not rest:
            print("error: issue subcommand required", file=sys.stderr)
            return 1
        subcmd = rest[0]
        if subcmd == "create":
            return cmd_issue_create(rest[1:])
        elif subcmd == "list":
            return cmd_issue_list(rest[1:])
        elif subcmd == "view":
            return cmd_issue_view(rest[1:])
        elif subcmd == "edit":
            return cmd_issue_edit(rest[1:])
        elif subcmd == "close":
            return cmd_issue_close(rest[1:])
        elif subcmd == "reopen":
            return cmd_issue_reopen(rest[1:])
        else:
            print(f"error: unknown issue subcommand: {subcmd}", file=sys.stderr)
            return 1

    else:
        print(f"error: unknown command: {cmd}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
```

**Step 2: Make executable**

Run:
```bash
chmod +x tests/mock_gh/gh
```

**Step 3: Test mock gh manually**

Run:
```bash
export MOCK_GH_STATE=/tmp/mock_gh_test
tests/mock_gh/gh label create "type: bug" --description "Something broken"
tests/mock_gh/gh label list --json name
```

Expected: Label created message, then JSON array with label

Run:
```bash
tests/mock_gh/gh issue create --title "Test issue" --body "Body text" --label "type: bug"
tests/mock_gh/gh issue list --json number,title,state
```

Expected: Issue URL printed, then JSON array with issue

**Step 4: Clean up test state**

Run:
```bash
rm -rf /tmp/mock_gh_test
```

**Step 5: Commit**

```bash
git add tests/mock_gh/gh
git commit -m "feat: add Python mock gh CLI for testing"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create bats test helper

**Files:**
- Create: `tests/test_helper.bash`

**Step 1: Create test helper with setup functions**

```bash
#!/usr/bin/env bash
# test_helper.bash - Shared setup for bats tests

# Get the directory containing this helper
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# State directory for mock gh
export MOCK_GH_STATE="$TEST_DIR/test_data"

# Add mock gh to PATH (before real gh)
export PATH="$TEST_DIR/mock_gh:$PATH"

# Setup function called before each test
setup() {
  # Ensure test_data directory exists
  mkdir -p "$MOCK_GH_STATE"
}

# Setup function called once before all tests in a file
setup_file() {
  # Clean test_data at the start of each test file
  rm -rf "$TEST_DIR/test_data"
  mkdir -p "$TEST_DIR/test_data"
}

# Helper to run gbeads command
run_gbeads() {
  run "$PROJECT_ROOT/gbeads" "$@"
}

# Helper to check mock gh state files
get_issues() {
  cat "$MOCK_GH_STATE/issues.json" 2>/dev/null || echo "[]"
}

get_labels() {
  cat "$MOCK_GH_STATE/labels.json" 2>/dev/null || echo "[]"
}
```

**Step 2: Commit**

```bash
git add tests/test_helper.bash
git commit -m "feat: add bats test helper with mock gh setup"
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Create initial smoke test

**Files:**
- Create: `tests/smoke.bats`

**Step 1: Create smoke test for mock gh and gbeads**

```bash
#!/usr/bin/env bats

load test_helper

@test "mock gh is in PATH" {
  run which gh
  assert_success
  [[ "$output" == *"mock_gh/gh"* ]]
}

@test "mock gh can create labels" {
  run gh label create "test-label" --description "A test label"
  assert_success
  assert_output --partial "Label created"
}

@test "mock gh can list labels as JSON" {
  gh label create "label-1" --description "First"
  run gh label list --json name
  assert_success
  assert_output --partial "label-1"
}

@test "mock gh can create issues" {
  run gh issue create --title "Test Issue" --body "Body"
  assert_success
  assert_output --partial "issues/1"
}

@test "mock gh can list issues as JSON" {
  gh issue create --title "Issue 1" --body "Body 1"
  gh issue create --title "Issue 2" --body "Body 2"
  run gh issue list --json number,title
  assert_success
  assert_output --partial "Issue 1"
  assert_output --partial "Issue 2"
}

@test "mock gh can view issue" {
  gh issue create --title "View Test" --body "View body"
  run gh issue view 1 --json number,title,body
  assert_success
  assert_output --partial "View Test"
}

@test "mock gh can edit issue" {
  gh issue create --title "Original" --body "Original body"
  run gh issue edit 1 --title "Updated"
  assert_success
  run gh issue view 1 --json title
  assert_output --partial "Updated"
}

@test "mock gh can close and reopen issue" {
  gh issue create --title "Lifecycle Test" --body "Body"
  run gh issue close 1
  assert_success
  run gh issue view 1 --json state
  assert_output --partial "closed"
  run gh issue reopen 1
  assert_success
  run gh issue view 1 --json state
  assert_output --partial "open"
}

@test "gbeads --help works" {
  run_gbeads --help
  assert_success
  assert_output --partial "gbeads - GitHub issue wrapper"
}

@test "gbeads --version works" {
  run_gbeads --version
  assert_success
  assert_output --partial "gbeads version"
}
```

**Step 2: Install bats helpers (if not already installed)**

Check if bats-assert is available:

Run:
```bash
brew list bats-core || brew install bats-core
```

If bats-assert/bats-support not available via brew, install locally:

Run:
```bash
mkdir -p tests/test_helper
git clone --depth 1 https://github.com/bats-core/bats-support.git tests/test_helper/bats-support
git clone --depth 1 https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert
```

**Step 3: Update test_helper.bash to load bats-assert**

Add at the top of `tests/test_helper.bash`, after the shebang:

```bash
# Load bats helpers
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
```

**Step 4: Run tests**

Run:
```bash
bats tests/smoke.bats
```

Expected: All tests pass

**Step 5: Update .gitignore to exclude bats helper repos if cloned locally**

If you cloned bats-support/bats-assert locally, add to `.gitignore`:

```gitignore
# Bats helper libraries (if cloned locally)
tests/test_helper/bats-support/
tests/test_helper/bats-assert/
```

**Step 6: Commit**

```bash
git add tests/smoke.bats tests/test_helper.bash
git add .gitignore  # if updated
git commit -m "feat: add smoke tests for mock gh and gbeads"
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Update Makefile test target

**Files:**
- Modify: `Makefile`

**Step 1: Ensure test target runs correctly**

The Makefile already has `test: bats tests/`. Verify it works:

Run:
```bash
make test
```

Expected: All tests pass

**Step 2: Commit if any changes needed**

If Makefile needed changes:

```bash
git add Makefile
git commit -m "chore: update Makefile test target"
```
<!-- END_TASK_5 -->

<!-- START_TASK_6 -->
### Task 6: Verify Phase 2 completion

**Step 1: Verify mock gh works**

Run:
```bash
export MOCK_GH_STATE=/tmp/phase2_verify
tests/mock_gh/gh label create "type: feature"
tests/mock_gh/gh issue create --title "Test" --body "Body" --label "type: feature"
tests/mock_gh/gh issue list --json number,title,labels
rm -rf /tmp/phase2_verify
```

Expected: Label created, issue created, list shows issue with label

**Step 2: Verify bats can run with mock in PATH**

Run:
```bash
make test
```

Expected: All tests pass

**Step 3: Verify test_data persists after tests**

Run:
```bash
ls tests/test_data/
```

Expected: Shows issues.json and/or labels.json (files from last test run)
<!-- END_TASK_6 -->
