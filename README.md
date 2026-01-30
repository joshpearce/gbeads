# gbeads

Lightweight GitHub issue wrapper for work organization. Work in progress.

Inspired by [steveyegge/beads](https://github.com/steveyegge/beads).

The skill is aware of, [ed3d-plugins, ed3d-plan-and-execute](https://github.com/ed3dai/ed3d-plugins) though not condoned by Ed.

gbeads wraps the `gh` CLI to provide work organization primitives using GitHub issues:
- **Type labels**: feature, user story, task, bug
- **Metadata blocks**: Collapsible HTML tables for depends_on, claimed_by, parent fields
- **Task lists**: Parent/child relationships via GitHub checkboxes
- **Dependencies**: Track blocking relationships between issues

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
- Python 3 (must be available as `python3` in PATH)

## Quick Start

```bash
# Initialize type labels in your repo
gbeads init

# Create issues
gbeads create feature "User authentication"
gbeads create task "Implement login form" --parent 1
gbeads create task "Add validation" --parent 1

# List and filter
gbeads list --type task
gbeads list --unclaimed

# Claim work
gbeads claim 2 agent-001

# View and update
gbeads show 2
gbeads update 2 --title "Build login form component"

# Manage dependencies
gbeads depends 3 --add 2    # Task #3 depends on #2

# Manage lifecycle
gbeads close 2
gbeads reopen 2
```

## Commands

See [docs/usage.md](docs/usage.md) for full command reference.

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
