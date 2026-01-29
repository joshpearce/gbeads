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
