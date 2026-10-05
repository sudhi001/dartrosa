#!/usr/bin/env python3
# Copyright 2026 The DartRosa Authors
# SPDX-License-Identifier: Apache-2.0

"""Checks relative links (and #anchors) in the repository's Markdown files,
and that every SVG in docs/images parses as XML."""
import os
import re
import sys
import xml.dom.minidom

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
skip_dirs = {'.dart_tool', '.git', 'build', 'node_modules', '.claude'}
allowed_missing = ()


def slug(heading):
    s = heading.strip().lower()
    s = re.sub(r'[`*_]', '', s)
    s = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', s)
    s = re.sub(r'[^\w\- ]', '', s)
    return s.replace(' ', '-')


def anchors(path):
    out = set()
    in_code = False
    for line in open(path, encoding='utf-8'):
        if line.startswith('```'):
            in_code = not in_code
        if not in_code and line.startswith('#'):
            out.add(slug(line.lstrip('#')))
    return out


md_files = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in skip_dirs]
    rel = os.path.relpath(dirpath, root)
    if rel.startswith('conformance/forms'):
        continue
    for f in filenames:
        if f.endswith('.md'):
            md_files.append(os.path.join(dirpath, f))

link_re = re.compile(r'!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
problems = []
count = 0
for md in md_files:
    text = open(md, encoding='utf-8').read()
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    text = re.sub(r'`[^`\n]*`', '', text)
    for target in link_re.findall(text):
        if re.match(r'^[a-z]+:', target):
            continue
        count += 1
        path, _, anchor = target.partition('#')
        dest = os.path.normpath(os.path.join(os.path.dirname(md), path)) if path else md
        rel = os.path.relpath(dest, root)
        if not os.path.exists(dest):
            if rel.startswith(allowed_missing):
                continue
            problems.append(f'{os.path.relpath(md, root)}: missing {target}')
            continue
        if anchor and dest.endswith('.md') and anchor not in anchors(dest):
            problems.append(f'{os.path.relpath(md, root)}: no anchor {target}')

svgs = 0
for dirpath, _, filenames in os.walk(os.path.join(root, 'docs/images')):
    for f in filenames:
        if f.endswith('.svg'):
            svgs += 1
            try:
                xml.dom.minidom.parse(os.path.join(dirpath, f))
            except Exception as e:  # noqa: BLE001
                problems.append(f'{f}: {e}')

print(f'{len(md_files)} Markdown files, {count} relative links, {svgs} SVGs')
for p in problems:
    print(p)
sys.exit(1 if problems else 0)
