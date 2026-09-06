#!/usr/bin/env python3
"""역할별 expertise 파일 로더/갱신기 (09편: agent experts > generic agents).

파일 위치: factory/teams/expertise/<team>/<role>.md
형식: 헤더 주석 줄들 + `- YYYY-MM-DD: <교훈 한 줄>` 목록 (append-only, 최대 MAX_LESSONS줄).
파일 상단 3줄 안에 `locked: true`가 있으면 읽기 전용 — append가 거부된다
(09편: billing/DevOps처럼 훼손되면 안 되는 지식은 not-updatable로 고정).

사용법:
  expertise.py load <team> <role>              # 내용 출력 (없으면 빈 출력, exit 0)
  expertise.py append <team> <role> "<교훈>"    # 교훈 1줄 추가 + cap 적용
"""

import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAX_LESSONS = 40


def path_for(team: str, role: str) -> Path:
    return ROOT / "teams" / "expertise" / team / f"{role}.md"


def is_locked(text: str) -> bool:
    return any("locked: true" in ln for ln in text.splitlines()[:3])


def load(team: str, role: str) -> int:
    p = path_for(team, role)
    if p.exists():
        print(p.read_text(encoding="utf-8").rstrip())
    return 0


def append(team: str, role: str, lesson: str) -> int:
    lesson = " ".join(lesson.split())  # 한 줄로 정규화
    if not lesson or lesson.lower() in ("none", "n/a"):
        return 0
    p = path_for(team, role)
    if not p.exists():
        print(f"expertise file not found (seed it first): {p}", file=sys.stderr)
        return 1
    text = p.read_text(encoding="utf-8")
    if is_locked(text):
        print(f"expertise file is locked (read-only): {p}", file=sys.stderr)
        return 1
    lines = text.rstrip().splitlines()
    header = [ln for ln in lines if not ln.startswith("- ")]
    lessons = [ln for ln in lines if ln.startswith("- ")]
    lessons.append(f"- {date.today().isoformat()}: {lesson}")
    lessons = lessons[-MAX_LESSONS:]  # cap: 오래된 교훈부터 버림
    p.write_text("\n".join(header + lessons) + "\n", encoding="utf-8")
    return 0


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, team, role = sys.argv[1], sys.argv[2], sys.argv[3]
    if cmd == "load":
        return load(team, role)
    if cmd == "append":
        if len(sys.argv) != 5:
            print("usage: expertise.py append <team> <role> <lesson>", file=sys.stderr)
            return 2
        return append(team, role, sys.argv[4])
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
