# Metadata Format and Body Editing Design

## Summary

This design replaces gbeads' current YAML frontmatter metadata format with a collapsible HTML `<details>` block containing a markdown table. The new format improves the GitHub web UI experience by hiding implementation metadata from casual viewers while keeping it accessible when needed. Additionally, the design introduces `--body` flag support for both `create` and `update` commands, allowing users to add descriptive content to issues beyond just the title.

The implementation follows the codebase's established pattern of using embedded Python for parsing (already used for JSON in `cmd_list` and `cmd_show`) while keeping generation in pure bash heredocs. The work is split into two phases: Phase 1 migrates all existing parsing and generation functions to the new HTML table format, and Phase 2 adds the body content editing capability. The three-section structure (metadata block, optional user body, optional tasks section) provides clear boundaries for parsing and reassembly during updates.

## Definition of Done

1. **Metadata format** - Issue bodies use a collapsible HTML `<details>` block with a table inside instead of YAML frontmatter. Collapsed by default with "Metadata" as the summary.

2. **Body content support** - `gbeads create` accepts `--body "description"` to add user content after the metadata block.

3. **Update command extended** - `gbeads update` gains `--body "description"` flag to modify the description section of existing issues (preserving metadata and task list).

4. **All parsing/generation functions updated** - `create_frontmatter`, `parse_frontmatter_field`, `update_frontmatter_field`, `get_body_content` work with the new HTML table format.

5. **Tests updated** - All tests pass with the new format.

## Glossary

- **Frontmatter**: A metadata block at the beginning of an issue body. Currently uses YAML format with `---` delimiters; this design replaces it with an HTML table format.
- **`<details>` element**: An HTML tag that creates a collapsible disclosure widget. When rendered on GitHub, content inside is hidden until the user clicks to expand it.
- **Metadata table fields**: Three structured fields stored in every issue: `depends_on` (array of blocking issue numbers), `claimed_by` (worker identifier or null), and `parent` (parent issue number or null).
- **Task list**: A markdown checklist section (`## Tasks`) in parent issues that tracks child issues using `- [ ] #N title` format. GitHub renders these as interactive checkboxes.
- **Body content**: User-provided description text that appears between the metadata block and the tasks section. Currently not supported; this design adds it via `--body` flag.
- **`gh` CLI**: GitHub's official command-line tool. gbeads wraps `gh` commands for all GitHub API interactions.
- **Heredoc**: A bash construct (`<<EOF ... EOF`) for embedding multi-line strings. Used in gbeads for generating formatted output without escaping.
- **Python helper functions**: Embedded Python code within the bash script for reliable parsing of structured data (JSON, and now HTML tables).

## Architecture

Issue bodies have three ordered sections:

```
<details>
<summary>Metadata</summary>

| Field | Value |
|-------|-------|
| depends_on | [] |
| claimed_by | null |
| parent | null |

</details>

[User body content - optional]

## Tasks
- [ ] #N Child task title
```

**Metadata block** - Always first, always present. Collapsible `<details>` element with markdown table inside. Three fields: `depends_on` (array), `claimed_by` (null or string), `parent` (null or number).

**Body content** - Optional user description. Appears between metadata and tasks. Set via `--body` flag on create or update.

**Tasks section** - Only present when issue has children. Managed by `children` command (unchanged).

### Parsing Strategy

Python helper functions for reliable HTML table parsing (consistent with existing JSON parsing pattern in gbeads):

- **`parse_metadata_field(body, field)`** - Extract field value from metadata table
- **`update_metadata_field(body, field, value)`** - Modify field in place, return updated body
- **`get_body_content(body)`** - Extract user content between `</details>` and `## Tasks`
- **`create_metadata(parent)`** - Generate new metadata block (bash heredoc, no Python)

## Existing Patterns

Investigation found Python already used for JSON parsing in `cmd_list` and `cmd_show`. This design follows that pattern by using embedded Python for HTML table parsing.

The `create_frontmatter` function currently uses bash heredoc - `create_metadata` will follow the same approach since generation doesn't require parsing.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Metadata Format Change
**Goal:** Replace YAML frontmatter with collapsible HTML table

**Components:**
- `create_metadata()` in `gbeads` - generates new HTML table format (replaces `create_frontmatter`)
- `parse_metadata_field()` in `gbeads` - Python helper to extract field from table
- `update_metadata_field()` in `gbeads` - Python helper to modify field in table
- `get_body_content()` in `gbeads` - Python helper to extract content after metadata

**Dependencies:** None (first phase)

**Done when:** All existing commands work with new format, existing tests updated and passing
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Body Content Support
**Goal:** Add `--body` flag to create and update commands

**Components:**
- `cmd_create()` in `gbeads` - add `--body` argument parsing, insert content after metadata
- `cmd_update()` in `gbeads` - add `--body` argument parsing, replace body content preserving metadata and tasks

**Dependencies:** Phase 1 (metadata format must be in place)

**Done when:** Can create issues with description, can update issue descriptions, tests pass for both
<!-- END_PHASE_2 -->

## Additional Considerations

**Body content extraction:** When extracting body content for update, must handle three cases:
1. No body content (just metadata, maybe tasks)
2. Body content with tasks section after
3. Body content with no tasks section

**Reassembly order:** When updating body content, always reassemble as: metadata + body + tasks (preserving each section's content except the one being modified).
