# Depends Command Design

## Summary

This design adds a `depends` command to gbeads for managing issue dependencies through metadata. The command follows the established `children` command pattern, using `--add` and `--remove` flags to modify the `depends_on` metadata field. Dependencies are stored as JSON arrays in the issue body's HTML metadata table (e.g., `[5, 7]`), with Python scripts handling array parsing and manipulation to avoid shell quoting complexities.

The implementation leverages existing metadata utility functions (`parse_metadata_field` and `update_metadata_field`) and follows gbeads' conventions: idempotent operations, issue existence validation, and prevention of self-dependencies. Unlike the bidirectional parent-child relationships managed through GitHub task lists, dependencies are unidirectional—if issue #6 depends on #5, only #6's metadata is modified. The command provides both read access (displaying current dependencies with issue titles) and write access (adding/removing dependency relationships).

## Definition of Done

- `gbeads depends <n>` displays current dependencies for an issue
- `gbeads depends <n> --add <m,p,...>` adds dependencies (issue n depends on m, p, ...)
- `gbeads depends <n> --remove <m>` removes dependencies
- Dependencies stored in `depends_on` metadata field as array (e.g., `[5, 7]`)
- Validates issues exist, prevents self-dependency
- Add/remove operations are idempotent
- All tests pass, lint passes

## Glossary

- **Metadata field**: Key-value data stored in an HTML table within the issue body, used by gbeads to track relationships (e.g., `depends_on`, `claimed_by`, `parent`)
- **Idempotent operation**: An operation that produces the same result whether executed once or multiple times (e.g., adding a dependency that already exists has no effect)
- **Unidirectional dependency**: A one-way relationship where issue A depending on issue B only modifies A's metadata, unlike bidirectional parent-child relationships
- **HTML table format**: The storage mechanism for metadata, rendered as a table in GitHub issue bodies with columns for field name and value
- **GitHub CLI (`gh`)**: The official GitHub command-line tool used by gbeads to read and write issue data
- **Self-dependency**: An invalid state where an issue would depend on itself, explicitly prevented by validation logic

## Architecture

Single command `gbeads depends` manages the `depends_on` metadata field. Follows the `cmd_children` pattern with `--add` and `--remove` flags for modifying relationships.

**Command interface:**
```bash
gbeads depends <number> [--add <n,m,...>] [--remove <n,m,...>]
```

**Data flow:**
1. Fetch issue body via `gh issue view`
2. Parse current `depends_on` value from metadata table
3. Modify array based on flags (add/remove issue numbers)
4. Update metadata via `update_metadata_field`
5. Save via `gh issue edit --body`

**Metadata format:**
- Empty: `| depends_on | [] |`
- With dependencies: `| depends_on | [5, 7] |`

Dependencies are one-way: if issue #6 depends on #5, only #6's metadata is modified. No bidirectional sync.

## Existing Patterns

Investigation found `cmd_children` (lines 867-958) uses identical structure:
- `--add` and `--remove` flags with comma-separated issue numbers
- Validates each issue exists before operating
- Uses `parse_metadata_field` and `update_metadata_field` for metadata manipulation
- Idempotent operations (adding existing item is no-op, removing missing item is no-op)

This design follows that pattern exactly for consistency.

**Metadata functions** (lines 103-172):
- `parse_metadata_field "body" "field"` - extracts value from HTML table
- `update_metadata_field "body" "field" "value"` - updates value in HTML table

Both use Python with stdin to avoid shell quoting issues. The `depends_on` field will be stored as a string representation of an array (`[5, 7]`) and parsed/manipulated with Python.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Core Command Implementation

**Goal:** Implement `cmd_depends` function with display, add, and remove functionality

**Components:**
- `cmd_depends()` function in `/Users/josh/code/gbeads/gbeads`
- Case statement update in main dispatch (around line 970)
- Helper function for parsing/updating array values in metadata

**Dependencies:** None (builds on existing metadata functions)

**Done when:**
- `gbeads depends <n>` displays dependencies
- `gbeads depends <n> --add <m>` adds dependency
- `gbeads depends <n> --remove <m>` removes dependency
- Validates issues exist, prevents self-dependency
- All new tests pass, `make test` passes, `make lint` passes
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Documentation Update

**Goal:** Update usage documentation and CLAUDE.md

**Components:**
- `/Users/josh/code/gbeads/docs/usage.md` - add depends command reference
- `/Users/josh/code/gbeads/CLAUDE.md` - update Commands section

**Dependencies:** Phase 1 complete

**Done when:** Documentation accurately reflects new command
<!-- END_PHASE_2 -->

## Additional Considerations

**Error handling:**
- Missing dependency issues emit warning and continue with valid ones
- Self-dependency returns error and exits without modifying metadata
- Non-existent target issue returns error immediately

**Display format:**
```
Issue #6: Implement the widget core
Dependencies: #5 (Design the widget API), #7 (Setup build system)
```
Or when empty:
```
Issue #6: Implement the widget core
Dependencies: none
```
