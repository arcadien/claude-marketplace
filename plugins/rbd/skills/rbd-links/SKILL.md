---
name: rbd-links
description: Links every requirement ID cited in requirements/*.md and docs/architecture.md to its heading, or checks those links. Invoke when the user types /rbd-links, asks to "link the requirement IDs", "fix requirement links" or "check requirement anchors".
---

# RBD Links

Runs the script `rbd_links.py`, next to this file, on the project root (the directory holding `.rbd/config.yml`).

## Apply — `/rbd-links`

1. Run `python3 <this skill's directory>/rbd_links.py <project root>`.
2. Every bare requirement ID cited in `requirements/*.md` and `docs/architecture.md` becomes a link to its
   `### ID` heading, relative to the citing file: `[FUNC-X-001](functional.md#func-x-001)` in a requirement file,
   `[FUNC-X-001](../requirements/functional.md#func-x-001)` in the architecture.
3. Left alone: headings, fenced code, code spans, HTML comments, existing links, ranges (`FUNC-X-001..015`)
   and IDs with no heading.
4. Show the user `git diff --stat`, then run the check below. Commit only on the user's request, as a format-only
   change: `plan: link requirement IDs` (list `plan` in `accepted_prefixes:` of `.rbd/plan-files.yml` for these files).

## Check — `/rbd-links --check`

Run `python3 <this skill's directory>/rbd_links.py --check <project root>`. It writes nothing and lists:

- every broken link: its target file has no heading for the ID, or the anchor is not the lowercase ID;
- every known ID cited without a link.

Exit status 1 means it found at least one. `/rbd-audit` runs this check as T8.
