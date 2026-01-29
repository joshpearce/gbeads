# gbeads Implementation Plan - Phase 1: Project Scaffolding

**Goal:** Initialize project structure with tooling

**Architecture:** Single-file bash script wrapper around gh CLI with bats-core testing infrastructure

**Tech Stack:** Bash, shellcheck, shfmt, pre-commit, bats-core, Python (for mock gh)

**Scope:** 8 phases from original design (phases 1-8)

**Codebase verified:** 2025-01-29 - greenfield project, only docs/design-plans/ exists

---

<!-- START_TASK_1 -->
### Task 1: Create gbeads executable stub

**Files:**
- Create: `gbeads`

**Step 1: Create the gbeads script with help output**

```bash
#!/usr/bin/env bash
# gbeads - GitHub issue wrapper for work organization
#
# A lightweight CLI that wraps `gh` to provide work organization
# primitives using GitHub issues with type labels and YAML frontmatter.

set -euo pipefail

readonly VERSION="0.1.0"

usage() {
  cat <<EOF
gbeads - GitHub issue wrapper for work organization

Usage:
  gbeads <command> [options]

Commands:
  init                Create type labels in current repo
  create <type> "title"   Create a typed issue (feature|story|task|bug)
  list                List issues with optional filters
  show <number>       Show issue details
  claim <number> <id> Claim an issue for a worker
  unclaim <number>    Release a claimed issue
  update <number>     Update issue title or type
  close <number>      Close an issue
  reopen <number>     Reopen a closed issue
  children <number>   Manage child issues in task list

Options:
  -h, --help          Show this help message
  -v, --version       Show version

Examples:
  gbeads init
  gbeads create task "Implement login form"
  gbeads create feature "User authentication" --parent 5
  gbeads list --type task --unclaimed
  gbeads claim 12 agent-001
  gbeads update 12 --title "New title"

EOF
}

version() {
  echo "gbeads version $VERSION"
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi

  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      version
      exit 0
      ;;
    init|create|list|show|claim|unclaim|update|close|reopen|children)
      echo "Error: Command '$1' not yet implemented" >&2
      exit 1
      ;;
    *)
      echo "Error: Unknown command '$1'" >&2
      echo "Run 'gbeads --help' for usage information." >&2
      exit 1
      ;;
  esac
}

main "$@"
```

**Step 2: Make executable and verify**

Run:
```bash
chmod +x gbeads
./gbeads --help
```

Expected: Prints usage information

Run:
```bash
./gbeads --version
```

Expected: `gbeads version 0.1.0`

**Step 3: Commit**

```bash
git add gbeads
git commit -m "feat: add gbeads executable stub with help output"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create .gitignore

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore file**

```gitignore
# Test data (preserved for inspection, cleared at test start)
tests/test_data/

# Node modules (from npm install during setup)
node_modules/

# OS files
.DS_Store

# Editor files
*.swp
*.swo
*~
.idea/
.vscode/
```

**Step 2: Verify**

Run:
```bash
cat .gitignore
```

Expected: Shows gitignore contents

**Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for test_data and node_modules"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create Makefile

**Files:**
- Create: `Makefile`

**Step 1: Create Makefile with test, lint, format targets**

```makefile
.PHONY: test lint format install-hooks

# Run all tests
test:
	bats tests/

# Run shellcheck and shfmt check
lint:
	shellcheck gbeads
	shfmt -d gbeads

# Format gbeads script in place
format:
	shfmt -w -i 2 -ci gbeads

# Install pre-commit hooks
install-hooks:
	pre-commit install
```

**Step 2: Verify Makefile syntax**

Run:
```bash
make --dry-run lint
```

Expected: Shows commands that would run (may fail if shellcheck not installed yet, that's OK)

**Step 3: Commit**

```bash
git add Makefile
git commit -m "chore: add Makefile with test, lint, format targets"
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Create .pre-commit-config.yaml

**Files:**
- Create: `.pre-commit-config.yaml`

**Step 1: Create pre-commit configuration**

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck

  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.8.0-1
    hooks:
      - id: shfmt
        args: ["-i", "2", "-ci"]
```

**Step 2: Install pre-commit hooks**

Run:
```bash
pre-commit install
```

Expected: `pre-commit installed at .git/hooks/pre-commit`

**Step 3: Run pre-commit on all files**

Run:
```bash
pre-commit run --all-files
```

Expected: All hooks pass (may auto-fix trailing whitespace or end-of-file)

**Step 4: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "chore: add pre-commit config with shellcheck and shfmt"
```
<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Create LICENSE file

**Files:**
- Create: `LICENSE`

**Step 1: Create MIT license**

```text
MIT License

Copyright (c) 2025 gbeads contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

**Step 2: Commit**

```bash
git add LICENSE
git commit -m "chore: add MIT license"
```
<!-- END_TASK_5 -->

<!-- START_TASK_6 -->
### Task 6: Create README.md

**Files:**
- Create: `README.md`

**Step 1: Create README with installation and usage**

```markdown
# gbeads

Lightweight GitHub issue wrapper for work organization.

gbeads wraps the `gh` CLI to provide work organization primitives using GitHub issues:
- **Type labels**: feature, user story, task, bug
- **YAML frontmatter**: depends_on, claimed_by, parent fields
- **Task lists**: Parent/child relationships via GitHub checkboxes

## Installation

Copy `gbeads` to somewhere in your PATH:

```bash
cp gbeads ~/.local/bin/
# or
sudo cp gbeads /usr/local/bin/
```

Requires:
- [GitHub CLI (gh)](https://cli.github.com/) - authenticated with `gh auth login`
- Bash 4.0+

## Quick Start

```bash
# Initialize type labels in your repo
gbeads init

# Create issues
gbeads create feature "User authentication"
gbeads create task "Implement login form" --parent 1

# List and filter
gbeads list --type task
gbeads list --unclaimed

# Claim work
gbeads claim 2 agent-001

# View and update
gbeads show 2
gbeads update 2 --title "New title"

# Manage lifecycle
gbeads close 2
gbeads reopen 2
```

## Commands

See [docs/usage.md](docs/usage.md) for full command reference (created in Phase 8).

## Development

```bash
# Install pre-commit hooks
make install-hooks

# Run tests
make test

# Lint
make lint

# Format
make format
```

## License

MIT
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with installation and usage"
```
<!-- END_TASK_6 -->

<!-- START_TASK_7 -->
### Task 7: Verify Phase 1 completion

**Step 1: Verify gbeads help works**

Run:
```bash
./gbeads --help
```

Expected: Usage information displayed

**Step 2: Verify lint passes**

Run:
```bash
make lint
```

Expected: No errors from shellcheck or shfmt

**Step 3: Verify pre-commit passes**

Run:
```bash
pre-commit run --all-files
```

Expected: All hooks pass

**Step 4: Final commit if any changes**

If pre-commit made any auto-fixes:

```bash
git add -A
git commit -m "chore: apply pre-commit fixes"
```
<!-- END_TASK_7 -->
