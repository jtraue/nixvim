"""
Orphan/broken-link checker for a vimwiki-style notes tree.

Reports:
  - broken links: [[...]] or markdown [text](target) links that don't
    resolve to any existing page in the tree, and also don't resolve to
    any other real file on disk (images, PDFs, exported diagrams, ...).
  - orphan pages: pages that exist but are never linked to from anywhere
    else in the tree (excluding a configurable set of directories, since
    diary/meeting-notes pages are normally reached by date, not by link).

Only paths, link targets, and link text are ever printed - never full note
bodies. Run this yourself; nothing it prints goes anywhere but your terminal.

Usage:
  wiki-link-check /path/to/wiki/notes
  wiki-link-check /path/to/wiki/notes --ext .wiki,.md \
      --exclude-dir diary,meeting_notes --index index
"""

import argparse
import posixpath
import re
import sys
import urllib.parse
from pathlib import Path

WIKI_LINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
MD_LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
FENCE_RE = re.compile(r"^\s*(```|~~~)")


def canon(path_str: str) -> str:
    """Normalize a page path for matching: case/space/underscore/hyphen-insensitive."""
    path_str = path_str.replace("\\", "/")
    path_str = re.sub(r"[-_\s]+", " ", path_str)
    return path_str.strip().lower()


def strip_ext(path_str: str, exts) -> str:
    for ext in exts:
        if path_str.lower().endswith(ext):
            return path_str[: -len(ext)]
    return path_str


def iter_lines_outside_fences(text: str):
    in_fence = False
    for lineno, line in enumerate(text.splitlines(), start=1):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        yield lineno, line


def extract_links(line: str):
    """Yield (raw_target, raw_match_text) for wiki- and markdown-style links on a line."""
    for m in WIKI_LINK_RE.finditer(line):
        inner = m.group(1)
        target = inner.split("|", 1)[0].strip()
        yield target, m.group(0)

    for m in MD_LINK_RE.finditer(line):
        target = m.group(1).strip()
        if not target or target.startswith("#"):
            continue
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.\-]*://", target):
            continue  # external URL
        if target.startswith("mailto:"):
            continue
        yield target, m.group(0)


def build_index(root: Path, exts):
    """Map canonical page key -> actual file Path, for every page in the tree."""
    index = {}
    all_files = []
    for ext in exts:
        all_files.extend(root.rglob(f"*{ext}"))
    for f in sorted(set(all_files)):
        rel = f.relative_to(root)
        key = canon(strip_ext(str(rel), exts))
        index[key] = f
    return index


def resolve_page(raw_target: str, file_rel_dir: str, index, exts):
    """Try to resolve a link target against the page index (.wiki/.md pages)."""
    target = raw_target.strip()
    target = target.split("#", 1)[0]  # drop in-page anchor
    target = urllib.parse.unquote(target)
    target = strip_ext(target, exts)
    if not target:
        return None  # pure same-page anchor, nothing to resolve

    candidates = [target]
    if file_rel_dir not in ("", "."):
        candidates.append(f"{file_rel_dir}/{target}")

    for c in candidates:
        norm = posixpath.normpath(c)
        key = canon(norm)
        if key in index:
            return index[key]
    return None


def resolve_asset(raw_target: str, file_rel_dir: str, root: Path):
    """Fall back to checking whether the link target is a real file on disk
    (image, PDF, exported diagram, ...) rather than an indexed page."""
    target = raw_target.strip()
    target = target.split("#", 1)[0]
    target = urllib.parse.unquote(target)
    if not target:
        return None

    candidates = [target]
    if file_rel_dir not in ("", "."):
        candidates.append(f"{file_rel_dir}/{target}")

    root_resolved = root.resolve()
    for c in candidates:
        norm = posixpath.normpath(c)
        candidate_path = Path(norm) if posixpath.isabs(norm) else (root / norm)
        try:
            real = candidate_path.resolve()
            real.relative_to(root_resolved)  # stay inside the wiki tree
        except ValueError:
            continue
        if real.is_file():
            return real
    return None


def is_excluded(rel_path: Path, exclude_dirs):
    return any(part in exclude_dirs for part in rel_path.parts[:-1])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("wiki_root", type=Path)
    ap.add_argument("--ext", default=".wiki,.md", help="comma-separated page extensions (default: .wiki,.md)")
    ap.add_argument(
        "--exclude-dir",
        default="diary,meeting_notes",
        help="comma-separated top-level-relative dir names to exclude from ORPHAN detection "
        "(links inside them are still checked for brokenness); default: diary,meeting_notes",
    )
    ap.add_argument("--index", default="index", help="page name (no ext) treated as an entry point, never orphan")
    args = ap.parse_args()

    root = args.wiki_root.resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        sys.exit(1)

    exts = tuple(e if e.startswith(".") else f".{e}" for e in args.ext.split(","))
    exclude_dirs = {d.strip() for d in args.exclude_dir.split(",") if d.strip()}

    index = build_index(root, exts)
    linked_to = set()
    broken = []  # (source_rel_path, lineno, raw_target, raw_match_text)

    for key, path in sorted(index.items(), key=lambda kv: str(kv[1])):
        rel = path.relative_to(root)
        rel_dir = str(rel.parent) if rel.parent != Path(".") else ""
        text = path.read_text(errors="replace")
        for lineno, line in iter_lines_outside_fences(text):
            for raw_target, raw_match in extract_links(line):
                resolved = resolve_page(raw_target, rel_dir, index, exts)
                if resolved is not None:
                    linked_to.add(canon(strip_ext(str(resolved.relative_to(root)), exts)))
                    continue
                if resolve_asset(raw_target, rel_dir, root) is not None:
                    continue  # a real non-page file (image, PDF, ...), not broken
                if raw_target.split("#", 1)[0].strip():  # ignore pure same-page anchors
                    broken.append((str(rel), lineno, raw_target, raw_match))

    orphans = []
    for key, path in sorted(index.items(), key=lambda kv: str(kv[1])):
        rel = path.relative_to(root)
        if key == canon(args.index):
            continue
        if is_excluded(rel, exclude_dirs):
            continue
        if key not in linked_to:
            orphans.append(str(rel))

    print(f"Scanned {len(index)} pages under {root}\n")

    print(f"=== BROKEN LINKS ({len(broken)}) ===")
    if not broken:
        print("(none)")
    for src, lineno, target, raw in broken:
        print(f"{src}:{lineno}: {raw}  -> unresolved target '{target}'")
    print()

    print(f"=== ORPHAN PAGES ({len(orphans)}) ===")
    print(f"(excluding dirs: {', '.join(sorted(exclude_dirs)) or 'none'}; index page: {args.index})")
    if not orphans:
        print("(none)")
    for o in orphans:
        print(o)


if __name__ == "__main__":
    main()
