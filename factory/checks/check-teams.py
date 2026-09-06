#!/usr/bin/env python3
"""Validate factory/teams/*.yaml schema and referenced paths.

Exit code 0 means all checks passed; 1 means violations were found.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEAMS_DIR = ROOT / "factory" / "teams"

sys.path.insert(0, str(ROOT / "factory"))
from teamcfg import strip_comment, parse_block  # noqa: E402

errors = []

yaml_files = sorted(TEAMS_DIR.glob("*.yaml"))

for yaml_path in yaml_files:
    fname = yaml_path.name
    prefix = f"{fname}"

    try:
        with open(yaml_path, encoding="utf-8") as f:
            lines = [strip_comment(l.rstrip("\n")) for l in f]
        obj, _ = parse_block(lines, 0, 0)
    except ValueError as e:
        errors.append(f"{prefix}: parse error - {e}")
        continue

    if not isinstance(obj, dict):
        errors.append(f"{prefix}: top-level value must be a mapping")
        continue

    # 1) name
    if not isinstance(obj.get("name"), str):
        errors.append(f"{prefix}: name must be a string")

    # 2) process
    process = obj.get("process")
    if not isinstance(process, list) or len(process) == 0:
        errors.append(f"{prefix}: process must be a non-empty list")

    # 3) domains
    domains = obj.get("domains")
    if not isinstance(domains, list) or len(domains) == 0:
        errors.append(f"{prefix}: domains must be a non-empty list")
    else:
        for domain in domains:
            if not isinstance(domain, str):
                errors.append(f"{prefix}: domains item must be a string - {domain!r}")
                continue
            if Path(domain).is_absolute():
                errors.append(f"{prefix}: domains item must be relative, got absolute path - {domain}")
                continue
            resolved = (ROOT / domain).resolve()
            if not resolved.is_relative_to(ROOT):
                errors.append(f"{prefix}: domains item escapes ROOT - {domain}")
                continue
            if not resolved.exists():
                errors.append(f"{prefix}: domains path does not exist - {domain}")

    # 4) roles
    roles = obj.get("roles")
    if not isinstance(roles, dict):
        errors.append(f"{prefix}: roles must be a mapping")
        continue

    # 5) lead / verifier existence and adapter key
    for required_role in ("lead", "verifier"):
        role_def = roles.get(required_role)
        if not isinstance(role_def, dict):
            errors.append(f"{prefix}: roles.{required_role} is missing or not a mapping")
        elif "adapter" not in role_def:
            errors.append(f"{prefix}: roles.{required_role} is missing adapter")

    # 6) Validate prompt/appendix paths for every role.
    for role_name, role_def in roles.items():
        if not isinstance(role_def, dict):
            continue
        if "model" in role_def and not isinstance(role_def["model"], str):
            errors.append(f"{prefix}: roles.{role_name}.model이 str이 아님 — {role_def['model']!r}")
        model_profiles = role_def.get("modelProfiles")
        if model_profiles is not None:
            if not isinstance(model_profiles, dict):
                errors.append(f"{prefix}: roles.{role_name}.modelProfiles가 dict가 아님")
            else:
                for adapter_name, profiles in model_profiles.items():
                    if not isinstance(adapter_name, str):
                        errors.append(f"{prefix}: roles.{role_name}.modelProfiles adapter 키가 str이 아님 — {adapter_name!r}")
                        continue
                    if adapter_name not in ("claude", "codex", "agy", "pi"):
                        errors.append(f"{prefix}: roles.{role_name}.modelProfiles adapter가 알 수 없음 — {adapter_name}")
                    if not isinstance(profiles, dict):
                        errors.append(f"{prefix}: roles.{role_name}.modelProfiles.{adapter_name}가 dict가 아님")
                        continue
                    for profile_name, model_name in profiles.items():
                        if not isinstance(profile_name, str):
                            errors.append(f"{prefix}: roles.{role_name}.modelProfiles.{adapter_name} profile 키가 str이 아님 — {profile_name!r}")
                        if not isinstance(model_name, str):
                            errors.append(
                                f"{prefix}: roles.{role_name}.modelProfiles.{adapter_name}.{profile_name} 모델명이 str이 아님 — {model_name!r}"
                            )
                    if "standard" not in profiles:
                        errors.append(f"{prefix}: roles.{role_name}.modelProfiles.{adapter_name}에 standard 프로필 없음")
        for key in ("prompt", "appendix"):
            if key not in role_def:
                continue
            prompt_val = role_def[key]
            if not isinstance(prompt_val, str):
                errors.append(f"{prefix}: roles.{role_name}.{key} must be a string - {prompt_val!r}")
                continue
            if Path(prompt_val).is_absolute():
                errors.append(f"{prefix}: roles.{role_name}.{key} must be relative, got absolute path - {prompt_val}")
                continue
            resolved = (ROOT / prompt_val).resolve()
            if not resolved.is_relative_to(ROOT):
                errors.append(f"{prefix}: roles.{role_name}.{key} escapes ROOT - {prompt_val}")
                continue
            if not resolved.is_file():
                errors.append(f"{prefix}: roles.{role_name}.{key} file does not exist - {prompt_val}")

if errors:
    print("TEAMS CHECK FAILED:")
    print("\n".join(errors))
    sys.exit(1)

print(f"OK: validated {len(yaml_files)} team file(s)")
sys.exit(0)
