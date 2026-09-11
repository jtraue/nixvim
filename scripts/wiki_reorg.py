"""
Wiki folder-reorganization helper: given a set of old->new path moves,
relocates the files and rewrites every [[...]] / [text](target) link
across the tree - including relative links inside files that move
themselves - so the reorganization doesn't break links.

Only paths and link text are ever printed - never note bodies. Dry-run
by default; nothing on disk changes until you pass --apply.

Moves file format (plain text, one entry per line, written by you):
  # comments and blank lines are ignored
  Old/Path/File.wiki -> New/Path/File.wiki     # single file (rename/move)
  Old/Dir/ -> New/Dir/                         # whole directory, any file type

Usage:
  wiki-reorg <wiki_root> --moves-file moves.txt            # dry run
  wiki-reorg <wiki_root> --moves-file moves.txt --apply    # actually do it
"""

import argparse
import posixpath
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

WIKI_LINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
MD_LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)]+)\)")
FENCE_RE = re.compile(r"^\s*(```|~~~)")
EXTERNAL_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.\-]*://")


def canon(path_str: str) -> str:
    path_str = path_str.replace("\\", "/")
    path_str = re.sub(r"[-_\s]+", " ", path_str)
    return path_str.strip().lower()


def strip_ext(path_str: str, exts) -> str:
    for ext in exts:
        if path_str.lower().endswith(ext):
            return path_str[: -len(ext)]
    return path_str


def relpath_posix(target_rel_to_root: str, from_dir: str) -> str:
    start = from_dir if from_dir not in ("", ".") else "."
    return posixpath.relpath(target_rel_to_root, start)


def build_page_index(root: Path, exts):
    index = {}
    all_files = []
    for ext in exts:
        all_files.extend(root.rglob(f"*{ext}"))
    for f in sorted(set(all_files)):
        rel = f.relative_to(root)
        key = canon(strip_ext(str(rel), exts))
        index[key] = f
    return index


def resolve_with_mode(raw_target: str, file_rel_dir: str, page_index, exts, root: Path):
    """Resolve a link target to a real file, trying root-relative then
    file-relative, pages first then assets. Returns (resolved_path, mode,
    kind) or (None, None, None) if unresolved."""
    target = raw_target.strip()
    target = target.split("#", 1)[0]
    target = urllib.parse.unquote(target)
    if not target:
        return None, None, None
    target_no_ext = strip_ext(target, exts)

    page_candidates = [("root", target_no_ext)]
    if file_rel_dir not in ("", "."):
        page_candidates.append(("file", f"{file_rel_dir}/{target_no_ext}"))
    for mode, c in page_candidates:
        key = canon(posixpath.normpath(c))
        if key in page_index:
            return page_index[key], mode, "page"

    asset_candidates = [("root", target)]
    if file_rel_dir not in ("", "."):
        asset_candidates.append(("file", f"{file_rel_dir}/{target}"))
    root_resolved = root.resolve()
    for mode, c in asset_candidates:
        norm = posixpath.normpath(c)
        candidate_path = Path(norm) if posixpath.isabs(norm) else (root / norm)
        try:
            real = candidate_path.resolve()
            real.relative_to(root_resolved)
        except ValueError:
            continue
        if real.is_file():
            return real, mode, "asset"

    return None, None, None


def _has_ext(raw_target_no_anchor: str, exts) -> bool:
    return strip_ext(raw_target_no_anchor, exts) != raw_target_no_anchor


def _new_target_for(resolved_rel: str, mode: str, file_rel: Path, moves, keep_ext: bool):
    """Compute the rewritten link target string, or None if nothing about
    this occurrence actually needs to change."""
    target_moved = resolved_rel in moves
    file_moved = str(file_rel) in moves
    if mode == "root" and not target_moved:
        return None
    if mode == "file" and not (target_moved or file_moved):
        return None

    new_target_path = moves.get(resolved_rel, Path(resolved_rel))
    new_target_str = str(new_target_path).replace("\\", "/")
    if not keep_ext:
        new_target_str = strip_ext(new_target_str, (Path(new_target_path).suffix,))

    if mode == "root":
        return new_target_str

    new_file_rel = moves.get(str(file_rel), file_rel)
    new_file_dir = str(Path(new_file_rel).parent)
    return relpath_posix(new_target_str, new_file_dir)


def rewrite_wiki_link(inner, file_rel, file_rel_dir, page_index, exts, root, moves):
    pipe_parts = inner.split("|", 1)
    target_and_anchor = pipe_parts[0]
    desc = pipe_parts[1] if len(pipe_parts) > 1 else None
    hash_parts = target_and_anchor.split("#", 1)
    raw_target = hash_parts[0].strip()
    anchor = hash_parts[1] if len(hash_parts) > 1 else None

    resolved, mode, kind = resolve_with_mode(raw_target, file_rel_dir, page_index, exts, root)
    if resolved is None:
        return None
    resolved_rel = str(resolved.relative_to(root))
    keep_ext = kind == "asset" or _has_ext(raw_target, exts)
    new_target_str = _new_target_for(resolved_rel, mode, file_rel, moves, keep_ext=keep_ext)
    if new_target_str is None:
        return None

    pieces = new_target_str
    if anchor:
        pieces += "#" + anchor
    if desc is not None:
        pieces += "|" + desc
    return f"[[{pieces}]]"


def rewrite_md_link(link_text, raw_target_group, file_rel, file_rel_dir, page_index, exts, root, moves):
    m = re.match(r'^(\S+)(\s+"[^"]*")?$', raw_target_group.strip())
    if not m:
        return None
    raw_target = m.group(1)
    title_suffix = m.group(2) or ""

    resolved, mode, kind = resolve_with_mode(raw_target, file_rel_dir, page_index, exts, root)
    if resolved is None:
        return None
    resolved_rel = str(resolved.relative_to(root))
    raw_target_no_anchor = raw_target.split("#", 1)[0]
    keep_ext = kind == "asset" or _has_ext(raw_target_no_anchor, exts)
    new_target_str = _new_target_for(resolved_rel, mode, file_rel, moves, keep_ext=keep_ext)
    if new_target_str is None:
        return None

    return f"[{link_text}]({new_target_str}{title_suffix})"


def rewrite_file(path: Path, root: Path, rel: Path, rel_dir: str, page_index, exts, moves):
    text = path.read_text(errors="replace")
    lines = text.splitlines(keepends=True)
    out = []
    in_fence = False
    edits = []
    changed = False

    for lineno, raw_line in enumerate(lines, start=1):
        ending = ""
        content = raw_line
        if content.endswith("\r\n"):
            ending, content = "\r\n", content[:-2]
        elif content.endswith("\n"):
            ending, content = "\n", content[:-1]

        if FENCE_RE.match(content):
            in_fence = not in_fence
            out.append(raw_line)
            continue
        if in_fence:
            out.append(raw_line)
            continue

        spans = []
        for m in WIKI_LINK_RE.finditer(content):
            spans.append((m.start(), m.end(), "wiki", m))
        for m in MD_LINK_RE.finditer(content):
            target_group = m.group(2).strip()
            if not target_group or target_group.startswith("#"):
                continue
            if EXTERNAL_RE.match(target_group) or target_group.startswith("mailto:"):
                continue
            spans.append((m.start(), m.end(), "md", m))

        if not spans:
            out.append(raw_line)
            continue

        spans.sort(key=lambda s: s[0])
        pieces = []
        cursor = 0
        line_changed = False
        for start, end, kind, m in spans:
            if kind == "wiki":
                new_text = rewrite_wiki_link(m.group(1), rel, rel_dir, page_index, exts, root, moves)
            else:
                new_text = rewrite_md_link(m.group(1), m.group(2), rel, rel_dir, page_index, exts, root, moves)
            pieces.append(content[cursor:start])
            old_text = content[start:end]
            if new_text is not None and new_text != old_text:
                pieces.append(new_text)
                edits.append((lineno, old_text, new_text))
                line_changed = True
            else:
                pieces.append(old_text)
            cursor = end
        pieces.append(content[cursor:])
        out.append("".join(pieces) + ending)
        if line_changed:
            changed = True

    return "".join(out), changed, edits


def _add_move(moves, errors, lineno, old_rel, new_rel):
    if old_rel in moves:
        errors.append(f"moves file line {lineno}: '{old_rel}' already has a move defined")
        return
    if old_rel == new_rel:
        return
    moves[old_rel] = Path(new_rel)


def parse_moves(moves_path: Path, root: Path):
    all_files = [f for f in root.rglob("*") if f.is_file()]
    moves = {}
    errors = []
    for lineno, raw_line in enumerate(moves_path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "->" not in line:
            errors.append(f"moves file line {lineno}: missing '->': {raw_line!r}")
            continue
        old_s, new_s = (p.strip() for p in line.split("->", 1))
        if not old_s or not new_s:
            errors.append(f"moves file line {lineno}: empty side: {raw_line!r}")
            continue
        if old_s.endswith("/") != new_s.endswith("/"):
            errors.append(
                f"moves file line {lineno}: mismatched directory move "
                f"(one side has trailing '/', other doesn't): {raw_line!r}"
            )
            continue

        if old_s.endswith("/"):
            old_dir, new_dir = old_s.rstrip("/"), new_s.rstrip("/")
            prefix = old_dir + "/"
            matched = [f for f in all_files if str(f.relative_to(root)).replace("\\", "/").startswith(prefix)]
            if not matched:
                errors.append(f"moves file line {lineno}: no files found under directory '{old_dir}/'")
                continue
            for f in matched:
                rel = str(f.relative_to(root)).replace("\\", "/")
                new_rel = f"{new_dir}/{rel[len(prefix):]}"
                _add_move(moves, errors, lineno, rel, new_rel)
        else:
            if not (root / old_s).is_file():
                errors.append(f"moves file line {lineno}: '{old_s}' does not exist")
                continue
            _add_move(moves, errors, lineno, old_s, new_s)

    return moves, errors


def validate_destinations(moves, root: Path):
    errors = []
    old_keys = set(moves.keys())

    dest_counts = {}
    for old_rel, new_rel in moves.items():
        dest_counts.setdefault(str(new_rel), []).append(old_rel)
    for dest, sources in dest_counts.items():
        if len(sources) > 1:
            errors.append(f"multiple sources map to the same destination '{dest}': {sources}")

    for old_rel, new_rel in moves.items():
        new_key = str(new_rel)
        if new_key in old_keys:
            errors.append(
                f"chained move detected ('{new_key}' is also a source in this moves file) "
                "- not supported, split into two runs"
            )
        elif (root / new_rel).exists():
            errors.append(f"destination '{new_rel}' already exists on disk")

    return errors


def is_git_repo(root: Path) -> bool:
    return (
        subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--is-inside-work-tree"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("wiki_root", type=Path)
    ap.add_argument("--moves-file", type=Path, required=True)
    ap.add_argument("--ext", default=".wiki,.md", help="comma-separated page extensions (default: .wiki,.md)")
    ap.add_argument("--apply", action="store_true", help="actually perform the moves and edits (default: dry run)")
    args = ap.parse_args()

    root = args.wiki_root.resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        sys.exit(1)
    if not args.moves_file.is_file():
        print(f"error: moves file {args.moves_file} not found", file=sys.stderr)
        sys.exit(1)

    exts = tuple(e if e.startswith(".") else f".{e}" for e in args.ext.split(","))

    moves, parse_errors = parse_moves(args.moves_file, root)
    errors = parse_errors + validate_destinations(moves, root)
    if errors:
        print("=== ERRORS (nothing changed) ===")
        for e in errors:
            print(f"- {e}")
        sys.exit(1)

    if not moves:
        print("No moves to perform.")
        return

    page_index = build_page_index(root, exts)

    all_edits = {}
    for _key, path in sorted(page_index.items(), key=lambda kv: str(kv[1])):
        rel = path.relative_to(root)
        rel_dir = str(rel.parent) if rel.parent != Path(".") else ""
        new_text, changed, edits = rewrite_file(path, root, rel, rel_dir, page_index, exts, moves)
        if changed:
            all_edits[str(rel)] = (new_text, edits)

    print(f"=== MOVES ({len(moves)}) ===")
    for old_rel, new_rel in sorted(moves.items()):
        print(f"{old_rel}  ->  {new_rel}")
    print()

    total_link_edits = sum(len(e) for _, e in all_edits.values())
    print(f"=== LINK REWRITES ({total_link_edits} across {len(all_edits)} files) ===")
    for old_rel in sorted(all_edits):
        _, edits = all_edits[old_rel]
        for lineno, old_raw, new_raw in edits:
            print(f"{old_rel}:{lineno}: {old_raw}  ->  {new_raw}")
    print()

    if not args.apply:
        print("Dry run only - nothing was changed. Re-run with --apply to perform these moves and edits.")
        return

    use_git = is_git_repo(root)
    for old_rel, new_rel in moves.items():
        dst = root / new_rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        moved_with_git = False
        if use_git:
            result = subprocess.run(
                ["git", "-C", str(root), "mv", old_rel, str(new_rel)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            )
            moved_with_git = result.returncode == 0
        if not moved_with_git:
            (root / old_rel).rename(dst)

    for old_rel, (new_text, _edits) in all_edits.items():
        final_rel = moves.get(old_rel, Path(old_rel))
        (root / final_rel).write_text(new_text)

    print(f"Applied {len(moves)} moves and rewrote links in {len(all_edits)} files.")
    print("Run wiki-link-check again to confirm nothing is broken, and review `git diff`/`git status` before committing.")


if __name__ == "__main__":
    main()
