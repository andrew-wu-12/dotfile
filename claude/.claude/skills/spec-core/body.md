# Body → what the spec body may say

The rules for the spec body section, whether init writes it for the first
time or sync rewrites it to current truth. The profile supplies the
language, the subsections and their formats, and the terms to show and to
avoid. These rules apply on top of the profile.

## Current truth only

- The body states the intended end state. It is not a diff log and not a
  history.
- State facts. Do not narrate them: no "unchanged since Round N", no "added
  this round", no "checked, still the same".
- An item checked this round that came back unchanged keeps its exact
  existing text. If the "checked, no change" fact is worth keeping, record it
  as a Decision Log row.
- Use `[MISSING]` for any value no source states. Never invent one.

## Decision-log boundary

A decision about *how* to implement something — a library choice, a code
pattern, a config-directive shape — goes in the Decision Log, not the body.
The body states observable behavior or end state. The Decision Log states
why you got there.

## Formatting

- Short bullets, not prose. A sentence with more than one fact becomes a
  bullet list.
- One action or effect per bullet. Do not chain effects with "and then".
  Split them into sibling bullets, even if that adds an indent level.
- A table cell that needs more than one line moves to its own bullet group
  below the table.
- No justification asides. Drop parentheticals that explain why something
  is so, or that it is not changing. A reason worth keeping goes in the
  Decision Log.
