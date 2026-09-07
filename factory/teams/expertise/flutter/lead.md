# expertise: flutter/lead - lessons accumulated after successful runs.
#
# English only: this file is injected into LLM prompts on every run.
# Keep at most 40 concise, reusable lessons.

- seed: For single-file append tasks, explicitly tell the worker to preserve all existing content unchanged.
- 2026-09-07: Team YAMLs without a `modelProfiles` map only support the `standard` profile — passing `claude light` to `just member-build` when the team YAML has no light-profile mapping makes `delegate.sh` fail with exit code 1; check the team YAML for `modelProfiles` before requesting a non-default profile.
- 2026-09-08: Bash string args passed to `just member-build` go through shell double-quote expansion before reaching the recipe — literal `$var`/`${...}` (e.g. Dart string interpolation like `'$error'` or `'${count}'`) quoted in a task prompt triggers bash "bad substitution"; either escape every `$` as `\$` or describe the code pattern in prose instead of pasting literal interpolation syntax.
