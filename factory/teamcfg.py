#!/usr/bin/env python3
"""팀 YAML 서브셋 파서 (표준 라이브러리만) — 팀 선언 파일을 JSON으로 덤프.

pyyaml 의존성을 피하기 위한 미니 파서. 팀 YAML은 아래 서브셋만 쓴다:
  - 중첩 dict (공백 들여쓰기), 블록 리스트(`- item`), 인라인 리스트(`[a, b]`)
  - 스칼라(문자열/정수/불리언), `#` 주석
미지원(팀 YAML에서 금지): 멀티라인 문자열, 앵커/별칭, 따옴표 이스케이프.

사용법: teamcfg.py <team.yaml>  →  stdout에 JSON 한 줄
"""

import json
import re
import sys


def strip_comment(line):
    in_quote = None
    for i, ch in enumerate(line):
        if in_quote:
            if ch == in_quote:
                in_quote = None
        elif ch in "\"'":
            in_quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[:i]
    return line


def parse_scalar(s):
    s = s.strip()
    if s.startswith("[") and s.endswith("]"):
        inner = s[1:-1].strip()
        return [parse_scalar(x) for x in inner.split(",")] if inner else []
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        return s[1:-1]
    if s == "true":
        return True
    if s == "false":
        return False
    if re.fullmatch(r"-?\d+", s):
        return int(s)
    return s


def parse_block(lines, i, indent):
    """lines[i]부터 들여쓰기 indent인 블록 하나를 파싱. (obj, 다음 인덱스) 반환."""
    obj = None
    while i < len(lines):
        raw = lines[i]
        stripped = raw.strip()
        if not stripped:
            i += 1
            continue
        cur = len(raw) - len(raw.lstrip(" "))
        if cur < indent:
            break
        if cur > indent:
            raise ValueError(f"line {i + 1}: unexpected indent")
        if stripped.startswith("- "):
            if obj is None:
                obj = []
            if not isinstance(obj, list):
                raise ValueError(f"line {i + 1}: list item inside a mapping")
            obj.append(parse_scalar(stripped[2:]))
            i += 1
            continue
        if obj is None:
            obj = {}
        if not isinstance(obj, dict):
            raise ValueError(f"line {i + 1}: mapping key inside a list")
        key, sep, rest = stripped.partition(":")
        if not sep:
            raise ValueError(f"line {i + 1}: expected 'key:'")
        key, rest = key.strip(), rest.strip()
        if rest:
            obj[key] = parse_scalar(rest)
            i += 1
            continue
        # 블록 값: 다음 비어있지 않은 줄의 들여쓰기가 자식 블록
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        child_indent = (
            len(lines[j]) - len(lines[j].lstrip(" ")) if j < len(lines) else -1
        )
        if child_indent <= indent:
            obj[key] = None
            i += 1
        else:
            obj[key], i = parse_block(lines, j, child_indent)
    return obj, i


def main():
    if len(sys.argv) != 2:
        print("usage: teamcfg.py <team.yaml>", file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as f:
        lines = [strip_comment(l.rstrip("\n")) for l in f]
    obj, _ = parse_block(lines, 0, 0)
    print(json.dumps(obj, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
