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
