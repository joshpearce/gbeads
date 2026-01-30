# gbeads

Last verified: 2026-01-30

## Tech Stack
- Language: Bash 4.0+
- Dependencies: GitHub CLI (`gh`), Python 3 (JSON processing)
- Testing: bats-core (Bash Automated Testing System)
- Linting: ShellCheck, shfmt

## Commands
- `make test` - Run all bats tests
- `make lint` - Run ShellCheck
- `make format` - Format with shfmt
- `make install-hooks` - Install pre-commit hooks

## Project Structure
- `gbeads` - Main executable script (single file CLI)
- `tests/` - bats test files
- `tests/mock_gh/` - Mock gh CLI for offline testing
- `docs/usage.md` - Full command reference

## Purpose

Lightweight wrapper around `gh` CLI for work organization using GitHub issues. Provides:
- Type labels: feature, story, task, bug
- HTML metadata blocks: depends_on, claimed_by, parent fields (collapsible table)
- Task lists: Parent/child relationships via GitHub checkboxes

## Contracts

**Issue Types** (validated, maps to labels):
- `feature` -> `type: feature`
- `story` -> `type: user story`
- `task` -> `type: task`
- `bug` -> `type: bug`

**Metadata Format** (every issue body starts with):
```html
<details>
<summary>Metadata</summary>

| Field | Value |
|-------|-------|
| depends_on | [] |
| claimed_by | null |
| parent | null |

</details>
```

**Commands** (all require git repo with GitHub remote):
- `init` - Create type labels
- `create <type> "title" [--parent n] [--body "desc"]` - Create typed issue
- `list [filters]` - List issues
- `show <n>` - Show issue details
- `claim/unclaim <n> [worker]` - Manage claims
- `update <n> [--title/--type/--body]` - Update issue
- `close/reopen <n>` - Lifecycle
- `children <n> [--add/--remove]` - Manage task list
- `depends <n> [--add/--remove]` - Manage dependencies

## Key Invariants
- All type labels have `type: ` prefix
- Metadata block uses `<details>` with markdown table format
- Task list entries are `- [ ] #N title` format
- Claim fails if already claimed (no silent overwrite)
- Child updates sync to parent task list titles
- Dependencies are one-way (only dependent issue metadata changes)
- Self-dependency is prevented
- Dependency add/remove are idempotent

## Testing Notes
- Tests use mock gh in `tests/mock_gh/gh`
- Mock maintains state in `$TEST_DATA_DIR`
- Source `gbeads` for unit testing internal functions

## Boundaries
- Safe to edit: `gbeads`, `tests/`
- Configuration: `.shellcheckrc`, `.pre-commit-config.yaml`
