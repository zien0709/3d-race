# AGENTS.md

Compact ramp-up for AI agents working on this repo. This file points you at the right sources and warns about traps. Domain specifics live in `md/`.

---

## What this repo is

Godot 4.7 (GL Compatibility, Jolt Physics) 3D racing game with single-player time trial and EOS multiplayer. Project name `Z 3D Race`, main scene `res://main.tscn`.

Full architecture, scene layout, and per-feature edit-point map: **`md/core/AISTARTREADIT.txt`** (read first, every session).

Workflow rules, env traps, release SOP: **`md/core/AI_WORKFLOW.md`** (read second, every session).

Current Phase + known issues snapshot: **`md/status/PROJECT_STATUS.md`** (read third, every session).

Task-specific deep dives live under `md/domain/` and `md/status/`. Don't read `md/archive/` unless explicitly told to.

---

## Required reading order for every session

1. `md/core/AISTARTREADIT.txt`
2. `md/core/AI_WORKFLOW.md`
3. `md/status/PROJECT_STATUS.md`
4. Task-relevant `md/domain/*` or `md/status/*`

Skipping step 1+2 wastes a round of debugging — they are written from real foot-guns.

---

## Hard rules (skip these and you'll regret it)

### Editing Godot files

- **All `.gd`, `.tscn`, `.tres` edits MUST go through Godot MCP tools** (`godot-ai_script_patch`, `godot-ai_node_set_property`, `godot-ai_script_create`, `godot-ai_batch_execute`).
- **Do NOT use `edit` / `write` for those extensions.** Direct writes break `.uid` sidecars, scramble node order, and introduce parse errors.
- Markdown and other non-engine files are fine to edit normally.

### GDScript

- **Never use `:=` in `game_eval` or any eval context** — it triggers `EVAL_COMPILE_ERROR`. Use `var x = ...`.
- **Always `await` coroutine return values.** `PlayerStorage.load_profile()` and similar are coroutines; forgetting `await` gives `EVAL_RUNTIME_ERROR`.
- No `println` — use `print`.

### Shell is PowerShell 5.1, not bash

- No `head`, `tail`, `wc`, `rg`, `cat`, `&&`, `python3`. Use `Select-String`, `Get-Content`, full cmdlet names.
- Chain with `cmd1; if ($?) { cmd2 }`.
- **UTF-8 / special chars in args get mojibake'd** (`??` for em-dash, CJK). For commit messages, release notes, tag annotations: write a temp file first, then `-F <file>` (or `--cleanup=verbatim` for tags).

### Godot MCP runtime quirks

- `game_eval` returns `EVAL_GAME_NOT_READY` when the game window is backgrounded / minimized. Focus the window before evals.
- Screenshots cannot be inspected by the model — use `get_ui_elements` / `get_scene_tree` / `logs_read` for verification instead.
- If the game parks in a debugger break on boot (parse error during load): `project_manage(stop)` → fix → `project_run` again. Don't try to resume a broken boot.

### Commit cadence

- One logical step per commit. Conventional Commits format. Don't pile up a huge mixed bag and commit it all at once — git history is the rollback tool.
- After each fix: run the verify loop (`project_manage(stop)` → filesystem scan if you added a `class_name` → `project_run` → `logs_read` source=`editor` then `game`).
- Sub-agents (the task tool) can return empty shells — do disposable exploration through them, but do important implementation yourself.
- Append new lessons to `md/logs/lobby-refactor-log.md` with the next lesson number.

---

## Git remotes — easy to get backwards

| Remote | Repo | Push? |
|--------|------|-------|
| `origin` | `zien0709/3d-race` | **Yes** — canonical upstream (transferred from Z11430373 on 2026-11-17) |
| `fork` | (removed) | `Z11430373/3d-race` transferred to `zien0709`; `fork` remote removed after `git remote remove fork` |

Releases go to `origin` now (the remote table above). See `AI_WORKFLOW.md §3` for the full release SOP (tag, release notes, gh token dance).

---

## Autoloads you can rely on

Already wired in `project.godot`:

- `NetworkManager` — EOS init, login, peer management (HOST / CLIENT / SINGLEPLAYER)
- `LobbyManager` — EOS Lobbies (create / search / join / ready / start)
- `LeaderboardManager` — EOS Stats + Leaderboards (`race_time_ms`)
- `PlayerStorage` — cloud PDS profile (`profile.json`)
- `EnvironmentManager` — weather / time / wind / sun sync across peers
- `AuthManager` — thin delegation over `NetworkManager` (don't re-implement auth here)
- `TrackRegistry` — selected track lookup; `race_course_setup.gd` reads from it
- `UIAnimations` — UI tween helpers

Add new autoloads with `godot-ai_autoload_manage`. Always check `list` first to avoid duplicates.

---

## Lobby UI — current state

Phase D (Lobby refactor) is the active focus. Key entry points if you're touching lobby code:

- `ui/lobby/lobby_main.gd` — thin coordinator; wires component signals to `NetworkManager` / `LobbyManager`
- `ui/lobby/lobby.tscn` — flat structure; components self-build their children (no deep path dependencies)
- `ui/lobby/components/*` — header, inspector, showcase, chat, ready_button, room_overlay, lobby_browser, customize, toast

Chat-specific notes live in `md/status/chat-redesign-notebook.md`. Chat message bus passes through `NetworkManager.chat_message_received(sender, sender_id, text, tab)` — handler signatures must match all four params.

---

## Verify loop (copy-paste checklist)

After any change to `.gd` / `.tscn` / `.tres`:

1. `project_manage(stop)` if a game is running.
2. If you added a `class_name`, run `godot-ai_filesystem_manage` op=`scan` once so the class table refreshes.
3. `godot-ai_project_run`.
4. `godot-ai_logs_read source="editor"` then `source="game"` — expect zero parse / runtime errors.
5. For UI changes: `godot-ai_game_manage op="get_ui_elements"` to confirm tree shape; don't rely on screenshots.
6. Commit. Update `md/status/PROJECT_STATUS.md` if phase / known-issues shifted.

---

## Files other agents have flagged as "do not touch"

- `md/EXPLORATION_REPORT.md` (and `md/archive/*` generally)
- `md/multiplayer_plan.md`

These are other agents' work artifacts. Read-only.