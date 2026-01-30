---
name: using-gbeads-for-work-management
description: Use when starting work sessions, discovering deferred work during implementation, or completing development branches - provides work intake from GitHub issues and captures emerging work items for later
---

# Using gbeads for Work Management

gbeads is a CLI wrapper around GitHub issues that provides lightweight work organization. It tracks features, stories, tasks, and bugs with dependency management and agent coordination.

**Core principle:** gbeads is the source of truth for *what to work on*. ed3d-plan-and-execute workflows define *how to do the work*. They complement each other.

## When to Use

**Work intake (start of session):**
- User asks "what should I work on?" or "is there work to pick up?"
- Starting a new development session with no specific task
- Before beginning `/start-design-plan` when no clear direction given

**Work capture (during implementation):**
- Discovered tech debt that isn't blocking current work
- Found a bug unrelated to current task
- Noticed architectural inconsistency to address later
- "Nice to have" improvements outside current scope

**Work completion (end of branch):**
- After `finishing-a-development-branch` skill completes
- When closing a feature/story/task tracked in gbeads

**Do NOT use for:**
- Tracking individual implementation plan tasks (use TaskCreate/TaskUpdate)
- Mid-execution status updates (gbeads tracks work items, not progress within items)
- Work that doesn't need to persist beyond this session

## Quick Reference

| Action | Command |
|--------|---------|
| Find available work | `gbeads ready` |
| See all open items | `gbeads list` |
| View item details | `gbeads show <n>` |
| Claim before starting | `gbeads claim <n> <agent-id>` |
| Create new item | `gbeads create <type> "title" [--body "..."]` |
| Defer work for later | `gbeads create task "..." --body "..."` |
| Mark complete | `gbeads close <n>` |

**Issue types:** `feature`, `story`, `task`, `bug`

## Integration with ed3d-plan-and-execute

### Starting Work: gbeads → Design Plan

When the user has no specific task in mind, check gbeads for ready work:

```bash
gbeads ready
```

If work exists, present options to the user:

```
Available work in gbeads:
#3  task  Implement retry logic for API calls
#5  bug   Login fails on mobile Safari
#8  task  Add caching layer to user service

Would you like to:
1. Work on one of these items
2. Start something new
3. Show me more details about an item
```

**If user selects a gbeads item:**
1. Run `gbeads show <n>` to get full details
2. Claim the work: `gbeads claim <n> claude-session`
3. Use the issue description as input to `/start-design-plan` or proceed directly if scope is clear

**If scope is clear from the gbeads issue:**
- Small, well-defined tasks may skip design and go straight to implementation
- Bugs often have clear reproduction steps and can skip brainstorming
- Use judgment: ambiguity → design first; clarity → implement directly

### During Implementation: Capturing Deferred Work

During plan execution, you may discover work that should happen later. **Do not interrupt current work.** Capture it in gbeads instead.

**Types of deferred work:**

| Discovery | Type | Example |
|-----------|------|---------|
| Technical debt | `task` | "Refactor auth module to reduce duplication" |
| Non-blocking bug | `bug` | "Error toast doesn't disappear on mobile" |
| Architectural concern | `task` | "Evaluate moving to event-driven architecture for notifications" |
| Missing tests | `task` | "Add integration tests for payment flow" |
| Documentation gap | `task` | "Document rate limiting behavior in API docs" |

**Capturing syntax:**

```bash
gbeads create task "Refactor auth module to reduce duplication" --body "Found during OAuth implementation. The token refresh logic is duplicated in three places: src/auth/refresh.ts, src/api/middleware.ts, and src/services/session.ts. Should extract to shared utility."
```

**For bugs:**

```bash
gbeads create bug "Error toast doesn't disappear on mobile" --body "Discovered during login flow testing. Toast stays visible indefinitely on iOS Safari. Desktop Chrome works fine. Likely z-index or timer issue."
```

**Body content should include:**
- Where/when you discovered it
- Why it matters (impact)
- Any initial analysis or hypothesis
- Relevant file paths if known

**After capturing:** Continue with current work. The item is now tracked for later.

### Completing Work: Close and Unclaim

After the `finishing-a-development-branch` skill completes (merge, PR, or intentional discard):

**If work was claimed from gbeads:**

```bash
# Mark the work complete
gbeads close <n>

# Unclaim is optional when closing, but explicit is fine
gbeads unclaim <n>
```

**If the work was tracked as a child of a larger feature:**
- Closing a task automatically updates the parent's task list
- Check if parent feature is now complete: `gbeads children <parent-n>`

### Hierarchical Work

gbeads supports parent-child relationships:

```
Feature #1: User Authentication
├── Story #2: Login Flow
│   ├── Task #3: Build login form
│   ├── Task #4: Implement validation
│   └── Task #5: Add OAuth option
└── Story #6: Session Management
    └── Task #7: Token refresh logic
```

**When starting a feature from gbeads:**
- Check for existing breakdown: `gbeads children <n>`
- If no breakdown exists and feature is large, consider decomposing first
- Each story or task can become a separate ed3d-plan-and-execute cycle

## Agent Coordination

When multiple agents work on the same repository, gbeads prevents conflicts:

**Claiming semantics:**
- `gbeads ready` shows only unclaimed, unblocked work
- `gbeads claim <n> <agent-id>` marks work as in-progress
- Claimed work won't appear in other agents' `ready` output

**Recommended agent-id format:** `claude-<session-indicator>` (e.g., `claude-main`, `claude-worktree-auth`)

**If you encounter already-claimed work:**
```bash
gbeads show <n>  # Shows who claimed it
```

Don't override claims without user approval.

## Common Rationalizations - STOP

| Excuse | Reality |
|--------|---------|
| "I'll just remember this for later" | No. Context compacts. Capture in gbeads. |
| "This bug is small, I'll fix it now" | No. Stay focused. Capture and continue. |
| "No need to claim, I'm the only agent" | No. Claim anyway. Habits matter. |
| "I'll create the gbeads item after I finish" | No. Capture immediately while context is fresh. |
| "The issue description is clear, I don't need to show it" | No. Run `gbeads show` and present to user. |

## Workflow Examples

### Example 1: Starting a Session

```
User: What should I work on?

Agent: [runs gbeads ready]

gbeads shows:
#12  task  Add rate limiting to API endpoints
#15  bug   Search results pagination broken

Agent: There are 2 items ready in gbeads:

1. **Task #12:** Add rate limiting to API endpoints
2. **Bug #15:** Search results pagination broken

Would you like to work on one of these, or start something new?

User: Let's do the rate limiting

Agent: [runs gbeads show 12, gbeads claim 12 claude-session]

I've claimed Task #12. Here are the details:
[shows issue content]

This looks like it needs design work first. I'll use /start-design-plan with this context.
```

### Example 2: Discovering Deferred Work

```
[During implementation of OAuth feature]

Agent: While implementing the token refresh, I noticed the error handling
in src/api/client.ts doesn't retry on network failures. This is outside
our current scope but should be addressed.

[runs: gbeads create task "Add retry logic to API client" --body "..."]

Created Task #18. Continuing with OAuth implementation.
```

### Example 3: Completing Work

```
[After finishing-a-development-branch completes with merge]

Agent: Implementation complete and merged to main.

[runs: gbeads close 12]

Task #12 is now closed.

[runs: gbeads ready]

Remaining available work:
#15  bug   Search results pagination broken
#18  task  Add retry logic to API client (the one we just captured)

Would you like to continue with another item?
```

## Prerequisites

gbeads requires:
- GitHub CLI (`gh`) installed and authenticated
- Repository has a GitHub remote
- Labels initialized: `gbeads init` (one-time setup)

If `gbeads` command is not found, the repository may need setup. Ask the user.
