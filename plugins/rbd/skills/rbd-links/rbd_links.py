#!/usr/bin/env python3
"""Link every cited requirement ID to its heading (FUNC-LINKS-001).

usage: rbd_links.py [--check] [project_dir]

Apply mode rewrites bare IDs in requirements/*.md and docs/architecture.md as
[ID](<relative file>#<lowercase id>). Check mode writes nothing, prints every
broken requirement link and every bare known ID, and exits 1 if it found any.
"""
import os
import re
import sys
from pathlib import Path

DEFAULT_CATEGORIES = ["FUNC", "TECH", "PERF", "UI", "CONF", "PLAT"]


def categories(root):
    config = root / ".rbd" / "config.yml"
    match = config.exists() and re.search(r"^\s*categories:\s*\[(.*)\]", config.read_text(), re.M)
    if not match:
        return DEFAULT_CATEGORIES
    return [c.strip(" \"'") for c in match.group(1).split(",") if c.strip(" \"'")]


def id_pattern(cats):
    return r"\b(?:" + "|".join(map(re.escape, cats)) + r")(?:-[A-Z0-9]+)*-[0-9]+\b"


class Project:
    def __init__(self, root):
        self.root = root
        self.id_re = id_pattern(categories(root))
        self.headings = {}  # ID -> requirement file that holds its "### ID" heading
        for req_file in sorted((root / "requirements").glob("*.md")):
            for match in re.finditer(r"^###\s+(" + self.id_re + r")\s*$", req_file.read_text(), re.M):
                self.headings[match.group(1)] = req_file.resolve()
        # protected spans first: code spans, comments, existing links; then bare IDs (not ranges)
        self.token = re.compile(
            r"(?P<keep>`[^`]*`|<!--.*?-->|\[[^\]]*\]\([^)]*\))|(?P<id>" + self.id_re + r")(?!\.\.)"
        )
        self.link = re.compile(r"\[(" + self.id_re + r")\]\(([^)#]*)#([^)]*)\)")

    def files(self):
        arch = self.root / "docs" / "architecture.md"
        return sorted((self.root / "requirements").glob("*.md")) + ([arch] if arch.exists() else [])

    def target(self, req_id, citing):
        rel = os.path.relpath(self.headings[req_id], citing.resolve().parent)
        return f"[{req_id}]({rel}#{req_id.lower()})"

    def text_lines(self, path):
        """Yield (index, line) for lines outside headings, fenced code and multi-line comments."""
        fenced = commented = False
        for index, line in enumerate(path.read_text().split("\n")):
            if line.lstrip().startswith("```"):
                fenced = not fenced
                continue
            if commented:
                commented = "-->" not in line
                continue
            if line.lstrip().startswith("<!--") and "-->" not in line:
                commented = True
                continue
            if not fenced and not line.startswith("#"):
                yield index, line

    def apply(self, path):
        def replace(match):
            req_id = match.group("id")
            return self.target(req_id, path) if req_id in self.headings else match.group(0)

        lines = path.read_text().split("\n")
        for index, line in self.text_lines(path):
            lines[index] = self.token.sub(replace, line)
        path.write_text("\n".join(lines))

    def problems(self, path):
        for index, line in self.text_lines(path):
            where = f"{path.relative_to(self.root)}:{index + 1}"
            for match in self.token.finditer(line):
                if match.group("id") in self.headings:
                    yield f"{where}: {match.group('id')} is not linked"
                link = match.group("keep") and self.link.fullmatch(match.group("keep"))
                if link:  # a real link, not one shown in a code span or a comment
                    req_id, rel, anchor = link.groups()
                    linked = (path.resolve().parent / rel).resolve() if rel else path.resolve()
                    if self.headings.get(req_id) != linked or anchor != req_id.lower():
                        yield f"{where}: broken link {req_id} -> {rel}#{anchor}"


def main(args):
    check = "--check" in args
    rest = [a for a in args if a != "--check"]
    project = Project(Path(rest[0] if rest else ".").resolve())
    if not check:
        for path in project.files():
            project.apply(path)
        return 0
    found = [problem for path in project.files() for problem in project.problems(path)]
    print("\n".join(found) if found else "All requirement IDs are linked.")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
