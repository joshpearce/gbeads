# gbeads Design

## Summary

This document describes **gbeads**, a bash-based command-line tool that wraps the GitHub CLI (`gh`) to provide lightweight work organization primitives using GitHub issues. The tool introduces a type system for issues (feature, user story, task, bug) via labels, stores metadata like worker assignments and dependencies in YAML frontmatter blocks within issue bodies, and enables hierarchical task decomposition through GitHub's native task list syntax. The implementation is a single-file bash script that enforces current-repository scope by deriving the `--repo` flag from git remotes on every `gh` invocation.

The approach prioritizes simplicity and GitHub-native conventions: types are standard labels, relationships are markdown task lists (`- [ ] #12 Title`), and worker assignment lives in structured frontmatter that's human-readable and GitHub-compatible. A Python mock of `gh` provides stateful testing infrastructure via bats-core, enabling full command validation without real GitHub API calls. The phased implementation starts with project scaffolding and mock infrastructure, then builds core utilities for repository detection and frontmatter manipulation, followed by CRUD commands, and culminates in parent/child relationship management through synchronized task lists.

## Definition of Done

- [ ] `gbeads` executable script exists in repo root
- [ ] `gbeads init` creates four type labels (`type: feature`, `type: user story`, `type: task`, `type: bug`)
- [ ] `gbeads create <type> "title"` creates issues with correct label and YAML frontmatter
- [ ] `gbeads list` filters by type, claimed_by, and unclaimed status
- [ ] `gbeads show <number>` displays issue details
- [ ] `gbeads claim/unclaim` manages worker field in frontmatter
- [ ] `gbeads update` modifies title/type and syncs parent task list
- [ ] `gbeads close/reopen` manages issue state
- [ ] `gbeads children` manages parent/child relationships via task lists
- [ ] All commands enforce current-repo scope
- [ ] Python mock `gh` enables stateful testing
- [ ] All tests pass via `bats tests/`
- [ ] Pre-commit hooks (shellcheck, shfmt) configured and passing
- [ ] README with installation and usage instructions

## Glossary

- **bash**: Unix shell and command language used as the implementation language for the gbeads script
- **bats-core**: Bash Automated Testing System, a TAP-compliant testing framework for bash scripts
- **Frontmatter**: Structured metadata block (YAML format) inserted at the beginning of a document, commonly used in static site generators and adapted here for GitHub issue bodies
- **gh**: GitHub's official command-line interface for interacting with GitHub repositories, issues, PRs, and other features via terminal
- **GitHub task list**: Markdown checkbox syntax (`- [ ] item` or `- [x] item`) rendered as interactive checkboxes in GitHub issue/PR bodies
- **mock**: Test double that simulates the behavior of a real component (here, the `gh` CLI) for isolated testing
- **pre-commit hook**: Git hook that runs automated checks (linting, formatting) before allowing a commit to proceed
- **set -euo pipefail**: Bash strict mode flags (exit on error, error on undefined variables, propagate pipe failures)
- **shellcheck**: Static analysis tool for shell scripts that identifies common bugs and style issues
- **shfmt**: Shell script formatter that enforces consistent style
- **YAML**: Human-readable data serialization format commonly used for configuration and structured data

## Architecture

Single-file bash script wrapping `gh` CLI to provide work organization primitives using GitHub issues.

**Core components within `gbeads`:**
- **Command dispatcher** — parses subcommand and routes to handler function
- **Repo validator** — ensures execution in git repo with GitHub remote, derives `--repo` flag
- **Frontmatter manager** — parses/writes YAML block in issue body (depends_on, claimed_by, parent)
- **Task list manager** — parses/writes GitHub task list format for parent/child relationships

**Data model:**
- Issue types mapped to labels: `type: feature`, `type: user story`, `type: task`, `type: bug`
- Metadata stored in YAML frontmatter at top of issue body
- Parent/child relationships via GitHub task lists in parent's body

**Frontmatter format:**
```yaml
---
depends_on: []
claimed_by: null
parent: null
---
```

**Task list format (in parent issue body):**
```markdown
## Tasks
- [ ] #12 Implement login form
- [ ] #15 Add password validation
```

**Command interface:**
```
gbeads init                                    # Create type labels
gbeads create <type> "title" [--parent <n>]    # Create typed issue
gbeads list [--type <t>] [--claimed-by <id>] [--unclaimed]
gbeads show <number>
gbeads claim <number> <worker-id>
gbeads unclaim <number>
gbeads update <number> [--title "..."] [--type <t>]
gbeads close <number>
gbeads reopen <number>
gbeads children <number> [--add <n,...>] [--remove <n>]
```

**Current-repo enforcement:** Every command derives the GitHub repo from git remote and passes explicit `--repo owner/repo` to all `gh` calls.

## Existing Patterns

This is a greenfield project with no existing codebase patterns.

The design follows standard bash project conventions:
- Single executable script in repo root
- Functions defined before `main()`, `main "$@"` as final line
- `set -euo pipefail` for strict error handling
- bats-core for testing with helper libraries

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Project Scaffolding

**Goal:** Initialize project structure with tooling

**Components:**
- `gbeads` — executable script stub with usage help
- `Makefile` — test, lint, format targets
- `.pre-commit-config.yaml` — shellcheck and shfmt hooks
- `.gitignore` — excludes `tests/test_data/`, `node_modules/`
- `README.md` — installation and basic usage
- `LICENSE` — MIT

**Dependencies:** None

**Done when:** `./gbeads --help` prints usage, `make lint` passes, pre-commit hooks installed and passing
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Mock gh Infrastructure

**Goal:** Python mock `gh` that maintains state for testing

**Components:**
- `tests/mock_gh/gh` — Python script implementing gh CLI subset
- `tests/test_helper.bash` — bats setup that adds mock to PATH, clears test_data at suite start
- `tests/test_data/` — state directory (gitignored)

**Mock gh supports:**
- `gh label create <name> --description <desc>`
- `gh label list --json name`
- `gh issue create --title <t> --body <b> --label <l>` — returns issue number
- `gh issue list --label <l> --state <s> --json number,title,body,labels,state`
- `gh issue view <n> --json number,title,body,labels,state`
- `gh issue edit <n> --title <t> --body <b>`
- `gh issue close <n>` / `gh issue reopen <n>`

State stored as JSON files in `tests/test_data/`

**Dependencies:** Phase 1

**Done when:** Mock gh can create/list/view/edit issues, state persists in test_data, bats can run with mock in PATH
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: Core Utilities

**Goal:** Shared functions for repo validation and frontmatter handling

**Components in `gbeads`:**
- `get_repo()` — extracts owner/repo from git remote
- `require_repo()` — exits with error if not in valid repo
- `parse_frontmatter()` — extracts YAML block from issue body
- `update_frontmatter()` — modifies field in frontmatter, returns updated body
- `create_frontmatter()` — generates initial frontmatter block

**Dependencies:** Phase 2 (for testing)

**Done when:** Unit tests verify frontmatter parsing/generation, repo detection works
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: Init and Create Commands

**Goal:** Initialize labels and create typed issues

**Components in `gbeads`:**
- `cmd_init()` — creates four type labels via `gh label create`
- `cmd_create()` — creates issue with type label and frontmatter, handles `--parent` flag

**Behaviors:**
- `create` with `--parent` sets parent field in frontmatter and adds task list entry to parent
- Type validated against: feature, story, task, bug

**Dependencies:** Phase 3

**Done when:** `gbeads init` creates labels, `gbeads create task "foo"` creates issue with frontmatter, `--parent` links correctly
<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: List and Show Commands

**Goal:** Query and display issues

**Components in `gbeads`:**
- `cmd_list()` — lists issues with filters (--type, --claimed-by, --unclaimed)
- `cmd_show()` — displays single issue details

**Behaviors:**
- List filters by label for type, parses frontmatter for claimed_by filtering
- Show displays formatted issue with parsed frontmatter fields

**Dependencies:** Phase 4

**Done when:** `gbeads list --type task` filters correctly, `gbeads show 1` displays issue with frontmatter parsed
<!-- END_PHASE_5 -->

<!-- START_PHASE_6 -->
### Phase 6: Claim and Lifecycle Commands

**Goal:** Worker claiming and issue state management

**Components in `gbeads`:**
- `cmd_claim()` — sets claimed_by in frontmatter
- `cmd_unclaim()` — clears claimed_by
- `cmd_close()` — closes issue
- `cmd_reopen()` — reopens issue

**Dependencies:** Phase 5

**Done when:** Claim/unclaim modifies frontmatter, close/reopen changes issue state
<!-- END_PHASE_6 -->

<!-- START_PHASE_7 -->
### Phase 7: Update Command with Parent Sync

**Goal:** Modify issues and sync parent task lists

**Components in `gbeads`:**
- `cmd_update()` — updates title and/or type
- `sync_parent_title()` — when title changes, updates task list entry in parent issue
- `parse_task_list()` — extracts task list entries from issue body
- `update_task_list_title()` — modifies title for specific issue number in task list

**Behaviors:**
- `--title` updates issue title and syncs to parent if parent field set
- `--type` changes label (removes old type label, adds new)

**Dependencies:** Phase 6

**Done when:** Title update syncs to parent's task list, type change swaps labels correctly
<!-- END_PHASE_7 -->

<!-- START_PHASE_8 -->
### Phase 8: Children Command and Documentation

**Goal:** Manage task lists and complete documentation

**Components:**
- `cmd_children()` in `gbeads` — add/remove/list children in task list
- `docs/usage.md` — full command reference with examples

**Behaviors:**
- `children <n>` lists parsed task list entries
- `children <n> --add 5,6` appends to task list (fetches titles from issues)
- `children <n> --remove 5` removes from task list

**Dependencies:** Phase 7

**Done when:** Children command manages task lists, documentation complete, all integration tests pass
<!-- END_PHASE_8 -->

## Additional Considerations

**Error handling:** All commands validate arguments before gh calls. Invalid type returns error with valid types listed. Missing issue returns gh's error message. Not in git repo returns clear error.

**Frontmatter robustness:** Parser handles missing frontmatter (treats as empty defaults). Existing body content below frontmatter preserved on updates.
