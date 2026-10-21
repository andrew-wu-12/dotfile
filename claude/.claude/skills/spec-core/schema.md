# Schema → shape of the spec note

The structural facts about the spec note — where it lives, what its
frontmatter means, what sections it has. Every `spec-*` step that creates,
reads, or updates the note uses this file instead of restating it. The
profile supplies the concrete values (`SPECS`, `<id>`, language, tags,
template).

## Location

- Note: `$SPECS/<id>.md`.
- Round snapshots: `$SPECS/.rounds/<id>/round-NN.md`. A snapshot is
  immutable. `round-NN.md` == end-of-round-N state. Snapshots are the round
  boundary, not vault git history.
- Create a snapshot only with `~/bin/spec-snapshot.sh "$SPECS" <id>`. Diff
  rounds only with `~/bin/spec-round-diff.sh "$SPECS" <id> [BASELINE] [TARGET]`.

## Frontmatter fields

Shared by every profile. The profile adds its own (ID field, tags).

- `created` — `YYYY-MM-DD`, set once at init.
- `round` — current round number. Init sets 1. Each sync adds 1.
- `posted` — list of publish records, one per post write. Each entry:
  `{round, date, url?, description}`. `url` is the comment URL when a
  comment was posted. Omit it for a description-only re-sync.
  `description` is `synced` or `resynced`. This is the shape only. The post
  step decides which value to write.

## Sections (in order)

1. Title line and tracker link line — the profile's template.
2. Spec body, under the profile's heading — see `body.md`.
3. `## Open Questions (private — curate before spec-post)` — checkbox list.
   Older notes name `/mop-spec-post` or `hl-spec-post` in the heading; match
   the section by its `## Open Questions` prefix and leave the heading as is.
   Each item ends `· evidence: path:line` where evidence exists.
   - Waiting: `- [ ] <question>  ·  ⏳ <bucket> (YYYY-MM-DD)`. `<bucket>` is
     one of the profile's waiting buckets. The date is when the item was
     first deferred.
   - Never asked (headless run, or a note from before the marker existed):
     `- [ ] <question>` with no `⏳`.
   - Answered: `- [x] <question>  ·  → **<answer>**（<source>, YYYY-MM-DD）`.
4. `## Decision Log` — `| Date | Source | Decision |` table, append-only.
   - Headers and `Source` tags stay in English. Tags are the profile's
     source tags plus `dev` (an answer you gave in an interview).
   - Decision text uses the profile's note language.
   - A sync row starts with one of the profile's change reasons in brackets,
     or free text in the same brackets. A row that replaces an earlier
     decision ends with the profile's "replaces" suffix.
5. `## Round History` — `- **Round N** (date): summary`, append-only.
   - The `**Round N** (date):` label stays in English. The summary uses the
     profile's note language.
   - A sync entry ends with a count per change reason.
