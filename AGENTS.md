# AGENTS.md

This file defines how coding agents (including Codex) should operate in this repository.

## Project Context
- Stack: Flutter/Dart app with Android, iOS, Web, Linux, macOS, and Windows targets.
- Main app source: `lib/`
- Assets: `assets/`
- Tests: `test/`

## Core Workflow
1. Read relevant files first and keep changes scoped to the user request.
2. Prefer minimal, targeted edits over broad refactors.
3. Preserve existing architecture and naming unless the task explicitly asks to change it.
4. Run validation commands after edits when possible.
5. Summarize what changed, why, and any follow-up actions.

## Coding Conventions
- Follow Flutter and Dart style from `analysis_options.yaml`.
- Keep widgets and methods focused and readable.
- Add comments only where intent is non-obvious.
- Do not introduce unrelated dependency or formatting churn.
- Prefer null-safe, strongly typed Dart code.

## Validation Conventions
Run the smallest useful validation set for the change:
- `flutter analyze`
- `flutter test`
- If platform-specific code changed, run the relevant target build/test command.

If a command cannot run, report the reason clearly.

## Git Conventions
- Use Conventional Commits:
  - `feat: ...`
  - `fix: ...`
  - `chore: ...`
  - `refactor: ...`
  - `test: ...`
  - `docs: ...`
- Keep commit messages specific and imperative.
- Avoid mixing unrelated changes in one commit.

## Safety Rules
- Never delete or rewrite large sections unless requested.
- Never run destructive git commands (for example `reset --hard`) unless explicitly requested.
- Do not modify secrets, keys, or CI/release settings unless the task requires it.
- Ask for confirmation before significant architectural or dependency changes.

## File Scope Guidance
- UI screens/pages: `lib/screens/`
- Shared UI components: keep near usage or in existing shared locations.
- Firebase setup and generated options: update only when integration changes are requested.
- Generated platform files: avoid manual edits unless required by the task.

## Definition of Done
- Requested change is implemented.
- Relevant checks pass (or failures are explained).
- Diff is clean, focused, and reviewable.
- Final response includes impact and any next steps.