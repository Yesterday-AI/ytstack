# Sticky session status: showing what a session is doing at all times

**As of 2026-11-15.** Claude Code 2.1.325, codex-cli 0.169.0, Kimi Code CLI 2.6.2, tmux 3.8, macOS. Follow-up to issue #42 (status line for progress, to-do lists and operator notes). This note answers the narrower question below; #42's questions on operator notes and coordinator state stay open there.

## Question

How far can the fixed parts of each coding agent's terminal UI be changed? The status line is known: how many lines does it take, and are there other surfaces? The goal: when a session has a to-do list, show it sticky at all times, so an operator who switches between sessions sees at once what each one is doing. What is possible, and can ytstack ship it?

## Short answer

1. Claude Code has three usable surfaces. The status line takes any number of lines (60 rendered in a test, no cap found). A plugin cannot set it. A **mod** (a plugin with a JavaScript hooks module) can draw its own rows in the **band above the prompt**, ships inside a plugin, and needs no settings edit. Hooks can set the terminal title through `terminalSequence`.
2. The to-do list is readable from outside. Claude Code writes one JSON file per task to `~/.claude/tasks/session-<first 8 chars of session_id>/<n>.json` (interactive) or `~/.claude/tasks/<session_id>/` (`-p`). The status line JSON carries `session_id`, so a status line script finds the list. Tested live: it follows `TaskCreate` and `TaskUpdate` within one refresh.
3. The catch: on current models (Opus 5.x, Haiku 5.5 and others newer than Opus 4.7) Claude Code **does not give Claude the task tools by default**, so there is no list to show. `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` turns them back on. Without it the built-in list (Ctrl+T) and any mirror stay empty.
4. Codex has no custom status line command. `[tui] status_line` is a list of built-in items, and one of them, `task-progress`, shows `Tasks n/m` from the last `update_plan`. The plan itself is a history cell that scrolls away. `[tui] terminal_title` takes the same kind of item list. Kimi has a one-line status line command whose stdin has `sessionId` but no to-dos.
5. Recommended for ytstack: ship a `ytstack-status --tasks` segment (status line, works everywhere a command status line exists) and, as a second step, a small mod that draws the band. A tmux recipe covers the "many sessions side by side" view across hosts.

## Per host findings

### Claude Code (2.1.325, docs read 2026-11-15)

**Status line** ([docs](https://code.claude.com/docs/en/statusline)).

- Configured only in settings (`statusLine.type: "command"`, `command`, `padding`, `refreshInterval` >= 1 s, `hideVimModeIndicator`). `/statusline <description>` writes a script and edits the user's settings. A plugin cannot set it (unchanged since DECISIONS 2026-11-11).
- Output: "each `echo` or `print` statement displays as a separate row". ANSI colours and OSC 8 links work. The docs name no line limit.
- Width: the script cannot use `tput cols`; Claude Code sets `COLUMNS` and `LINES`. Long lines are cut with `…` (tested, see below).
- Refresh: once at session start and resume, then on a new assistant message, `/compact`, permission-mode change, vim toggle, a `command` change, a `refreshInterval` tick, and rate-limit or prompt-cache expiry times. Debounced at 300 ms. A new trigger cancels a running script. "The event-driven triggers can go quiet when the main session is idle, for example while a coordinator waits on background subagents."
- Exit code non-zero or empty output blanks the line. Hidden during permission prompts and the help menu. Blank until workspace trust is accepted. Outside fullscreen rendering, notifications share the row and can truncate it.
- Stdin JSON (documented and observed): `session_id`, `session_name`, `transcript_path`, `cwd`, `workspace.*`, `model.*`, `cost.*`, `context_window.*`, `effort`, `thinking`, `rate_limits.*`, `prompt_cache`, `pr.*`, `worktree.*`, `agent.name`, `output_style`, `version`. **No tasks or to-dos.** Observed keys in a fresh session: `context_window, cost, cwd, effort, exceeds_200k_tokens, fast_mode, model, output_style, session_id, thinking, transcript_path, version, workspace`.

**Built-in task list** ([interactive mode](https://code.claude.com/docs/en/interactive-mode#task-list), [tools reference](https://code.claude.com/docs/en/tools-reference#task-tool-availability), [env vars](https://code.claude.com/docs/en/env-vars)).

- Ctrl+T toggles "Claude's to-do checklist in the status area". It shows up to five tasks. An expanded list is restored on `--resume`/`--continue`. Observed: while expanded it stays above the prompt after the turn ends (`3 tasks (1 done, 1 in progress, 1 open)` plus one row per task). It is sticky in that sense, but only for the session in front of you.
- No setting changes its size or position.
- Since v2.1.268 the tools (`TaskCreate`, `TaskGet`, `TaskUpdate`, `TaskList`, or legacy `TodoWrite` with `CLAUDE_CODE_ENABLE_TASKS=0`) exist by default only on Opus 4.7, Sonnet 4.6, Haiku 4.5 and earlier. "On newer models, Claude keeps track of multi-step work without a written checklist." Opt in with `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` (v2.1.233+), `--allowedTools TaskCreate` or `--tools`. Background and cloud sessions always have them. This session (Opus 5.5) has no task tools, which matches the 348 empty `session-*` directories under `~/.claude/tasks/` on this machine.
- `CLAUDE_CODE_TASK_LIST_ID=<name>` shares one list across sessions in `~/.claude/tasks/<name>/`.

**Where the tasks live** (observed, not documented).

- Interactive session: `~/.claude/tasks/session-<first 8 hex chars of session_id>/`, created at session start, with `.lock` and `1.json`, `2.json`, ...
- `claude -p`: `~/.claude/tasks/<full session_id>/`.
- File shape: `{"id":"2","subject":"beta","description":"Task beta","status":"in_progress","blocks":[],"blockedBy":[]}`. `status` is `pending`, `in_progress` or `completed`.
- The directory scheme is an implementation detail and can change without notice. A reader should try `CLAUDE_CODE_TASK_LIST_ID`, then `session-<8>`, then the full id, and print nothing when none exists.
- Unverified: whether files are removed when all tasks complete or when the session ends. After the test sessions ended, the files were still there.

**Hooks** ([hooks reference](https://code.claude.com/docs/en/hooks)).

- `systemMessage`: a warning shown to the user. `additionalContext`: goes to Claude, not to the screen. Neither is a sticky surface.
- `terminalSequence`: Claude Code emits an allow-listed escape sequence for the hook (OSC 0/1/2/9/99/777 and BEL), so a hook can set the window title. Interactive sessions only, not from async hooks. Under tmux it needs `allow-passthrough on`.
- `TaskCreated` and `TaskCompleted` events exist (`task_id`, `task_subject`, `task_description`), no matcher. A `PostToolUse` hook with matcher `TaskCreate|TaskUpdate` also fires (tested).
- `sessionTitle` from `SessionStart` or `UserPromptSubmit` sets the session title, same as `/rename`.
- **Title conflict (tested):** Claude Code sets its own title (OSC 0, an animated glyph plus the session title) several times a second while working. A hook's OSC 2 title lasts until the next one. Only `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` stops that, and it also turns off the generated session title and OSC 7501 status reports.
- OSC 7501 Program Status Protocol ([terminal config](https://code.claude.com/docs/en/terminal-config#see-session-status-in-your-terminal), v2.1.295+): a supporting terminal shows working, waiting or done per session. Not inside tmux. Which terminals implement it: unverified.

**Mods** ([interface](https://code.claude.com/docs/en/plugins/mods/interface), [API](https://code.claude.com/docs/en/plugins/mods/api), [reference](https://code.claude.com/docs/en/plugins/mods/reference); reference "as of v2.1.290").

- A mod is a plugin with `hooks/hooks.json` naming a JavaScript module (`"modules": ["./register.js"]`). It ships in the plugin. No settings edit by the user.
- Render sites: a `Pane` (sidebar in a wide fullscreen terminal, framed region above the prompt otherwise), the band above the prompt (`AbovePrompt`, one row group per mod since v2.1.323, props include `maxRows`, `bodyColumns`, `isWorking`, `isCollapsed`), `$.ui.status(text)` (one line under the prompt, prefixed with the mod name), toasts, transcript rows, and restyling of the spinner, footer mode labels and the prompt hint.
- Data: `$.session.id()`, `$.session.messages()`, `$.fs.read/list` (any path, user's permissions), `$.agent.list()` (subagent status), `tool.call` events, `$.clock.every` for timers, `$.ui.invalidate('ui.render')` to redraw.
- Limits: a hook may run 10 s; trees over the element limits are not drawn. The user can collapse the band to one row (Ctrl+X Ctrl+A) and the mod cannot expand it. Organisations can block mods with `allowManagedModsOnly` or `allowManagedHooksOnly`; `disableAllHooks` stops them.
- VS Code and Desktop draw a subset (the band renders in Terminal and Desktop).

**Other surfaces.** Output styles change Claude's prose, not fixed UI. Spinner verbs and tips are settings (`spinnerTipsEnabled`); a mod can restyle the `Spinner` site. `footerLinksRegexes` adds link badges to the footer. None of these is a better place for a task list than the band or the status line.

### Codex CLI (0.169.0)

Read in source at tag `rust-v0.169.0` ([openai/codex](https://github.com/openai/codex), published 2026-11-13) by a research subagent. The item names were checked against the installed binary.

- **Status line**: `[tui] status_line = ["item", ...]` (`codex-rs/config/src/types.rs`, struct `Tui`), `status_line_use_colors`, interactive setup with `/statusline`. Items (`codex-rs/tui/src/bottom_pane/status_line_setup.rs`) include `model`, `model-with-reasoning`, `current-dir`, `project-name`, `git-branch`, `pull-request-number`, `run-state`, `context-used`, `context-remaining`, `five-hour-limit`, `weekly-limit`, `used-tokens`, `thread-id`, `thread-name`, `thread-title`, `workspace-headline` and **`task-progress`**. There is **no command item**, so no script can add text. One line (inferred from `status_line_from_segments`, not checked in detail).
- **Plan display**: `update_plan` (`{explanation?, plan: [{step, status: pending|in_progress|completed}]}`) emits `PlanUpdate`, rendered as a `PlanUpdateCell` checkbox list in the history (`codex-rs/tui/src/history_cell/plans.rs`). It scrolls away. The only sticky trace is `task-progress`: `Tasks {completed}/{total}` from the last plan (`chatwidget/status_surfaces.rs`), never the step text. The sidebar (`sidebar_width_percent`) holds side chats, not the plan.
- **Terminal title**: `[tui] terminal_title = [...]`, default `activity`, `thread-name`, `project-name`, also with `task-progress` (`bottom_pane/title_setup.rs`); `/title` sets it up.
- **Other `[tui]` keys**: `notification_settings` (`notifications`, `method`, `condition = unfocused|always`), `animations`, `show_tooltips`, `alternate_screen`, `fullscreen_transcript`, `theme` and more.
- **notify**: a program that receives one JSON argument, only for `agent-turn-complete` (`thread_id`, `turn_id`, `cwd`, `input_messages`, `last_assistant_message`); marked for removal in source (`codex-rs/hooks/src/legacy_notify.rs`).
- **Hooks**: SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, PostToolUse, PermissionRequest, Stop, SubagentStop and others. Output fields `systemMessage`, `additionalContext`, `continue`, `decision`, `updatedInput`, `suppressOutput`; nothing for the title or the footer. A PostToolUse hook matching `update_plan` should get the whole plan as `tool_input` (`core/src/tools/registry.rs`); read in source, **not observed live**. Plugins can ship hooks, behind a trust layer.
- **On disk**: `~/.codex/sessions/YYYY/MM/DD/rollout-<ts>-<thread-id>.jsonl`. The 400 newest local rollouts held no `update_plan` call, so the line shape is **unverified**. Reading the plan from the rollout is fragile; a PostToolUse hook that writes a small state file would be the reliable source (proposed, untested).
- **Observed locally**: the user's `~/.local/bin/codex` wrapper already adds `-c tui.status_line=[...]` for repositories with `.ytstack/`, without `task-progress`.
- **What a plugin can ship**: hooks. `status_line` and `terminal_title` are user config (`config.toml`, `-c`, or `/statusline`).

### Kimi Code CLI (2.6.2)

Read in source at [`MoonshotAI/kimi-code`](https://github.com/MoonshotAI/kimi-code) tag `@moonshot-ai/kimi-code@2.6.2` (commit 6a8493d, 2026-11-13) by the subagent. `KIMI_CODE_STATUS_LINE` and `SetTodoList` were found in the installed binary.

- **Status line** (`docs/en/configuration/config-files.md`, `apps/kimi-code/src/tui/utils/status-line-command.ts`): in `~/.kimi-code/tui.toml`, `[status_line].items` picks built-in slots (`mode`, `goal`, `model`, `tasks`, `cwd`, `git`, `tips`). `[status_line].command` replaces the footer with the **first stdout line** only. JSON on stdin (`model`, `cwd`, `gitBranch`, `permissionMode`, `planMode`, `contextUsage`, `sessionId`, `version`), 300 ms timeout, at most once per second, falls back to the built-in footer on failure, env `KIMI_CODE_STATUS_LINE=1`. No to-dos in the payload.
- **To-do display**: `SetTodoList` renders a card in the transcript (`tui/components/messages/tool-renderers/todo.ts`); not sticky. Whether the `tasks` slot means to-do progress or background tasks: unverified.
- **Hooks** (`docs/en/customization/hooks.md`): `[[hooks]]` in `config.toml`, events from SessionStart to Notification, including PostToolUse. A title field: unverified. `auto_session_title` exists.
- **On disk** (`docs/en/configuration/data-locations.md`): `~/.kimi-code/sessions/<workspaceId>/<sessionId>/` with `state.json` and `agents/main/wire.jsonl`; `~/.kimi-code/session_index.jsonl` maps ids to directories. Where the to-dos sit: unverified (probably `wire.jsonl`).
- **Observed locally**: `[status_line].command` already runs `bash ~/.kimi-code/ytstack-statusline.sh`.

### OpenCode, Gemini CLI, Cursor CLI (brief)

Not researched in depth; everything here is **unverified**. Local versions: OpenCode 2.2.7, Gemini CLI 0.67.0, Cursor CLI 2026.01.23. Gemini's bundle contains footer settings (string search only). Whether OpenCode's sidebar shows its to-do tool, whether Gemini can put status in the title, and whether Cursor CLI has a status line are open. None of these is a ytstack host today.

### Terminal level, independent of the agent

- **Window or tab title** (OSC 0/2): works in every terminal, but each agent writes its own title. In Claude Code the hook title loses to the built-in one unless the user disables it (tested above).
- **tmux status bar**: `status` takes `on`, `off` or `2` to `5` lines; each line is `status-format[n]`, and `#(cmd)` runs a command. Tested: `status 3` with two custom lines on tmux 3.8. Widths and refresh follow `status-interval`.
- **tmux pane borders**: `pane-border-status top` plus `pane-border-format '#{pane_index} #{@yt_task}'` puts one line per pane, visible for every session in a window at once. This is the closest thing to "see what every session is doing" without switching.
- **Mapping a session to a terminal**: the status line command and hooks inherit Claude Code's environment, so `TMUX_PANE` is set (observed `%0`). A status line script can write `tmux set-option -p -t "$TMUX_PANE" @yt_task "..."` and tmux shows it on the pane border. Tested: the pane option held `tasks 0/2 > one` after a live run. iTerm2 (`SetUserVar` OSC 1337, badges) and WezTerm (user vars, `format-tab-title`) offer the same pattern: unverified here.
- **Notifications**: Claude Code sends desktop notifications in Ghostty, Kitty and iTerm2 when it waits; mods can call `$.ui.notify`. Useful for "needs you", not for a sticky list.

## Measured / tested

All runs used an isolated tmux server (`tmux -L sticky`), `claude --settings '<json>'` or `--plugin-dir` for the session only, and Haiku 5.5. `~/.claude/settings.json` was not changed. Scripts are in `/tmp/sticky-test/` (not kept).

| Test | Result |
|---|---|
| Status line printing N lines, pane 140x50 | 3, 12 and 30 lines all rendered. 60 lines rendered too: the block grew upwards and pushed the prompt off the visible screen. No cap. |
| Same, pane 140x20, 12 lines | 12 rendered, prompt still visible above them. |
| One 300-character line, pane width 100 | Cut to the width with `…`. |
| `COLUMNS` / `LINES` in the script | Set (`cols=140 lines=50`). |
| OSC 2 printed by a status line script | Not applied; the title stayed Claude Code's own. |
| `claude -p` with `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`, three tasks | Files at `~/.claude/tasks/<session_id>/{1,2,3}.json`, shape as above. |
| Interactive session, same | Files at `~/.claude/tasks/session-<8>/`. A first prototype that only looked under the full id showed nothing. |
| Status line prototype reading that directory, live | Followed `TaskCreate` and each `TaskUpdate`: `tasks 0/3`, `[>] one` ... then `tasks 1/3`, `[x] one`, `[>] two`, within the next 4-second sample. Script run time 0.09 to 0.12 s with `jq`. |
| Mod drawing the band (`AbovePrompt`), reading the same files every 2 s | Validated with `claude plugin validate`, loaded with `--plugin-dir`, drew four rows above the prompt that followed the task updates, with a `[-]` collapse mark. Shown under Claude Code's own expanded list. Default (non-fullscreen) renderer. |
| `PostToolUse` hook (`TaskCreate|TaskUpdate`) returning `terminalSequence` OSC 2 | Hook fired three times. With `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` the title became `YT 0/2 one`. Without it, Claude Code's own title replaced it within four seconds. |
| tmux `status 3` with `status-format[1..2]` | Three status lines. |
| Status line script writing a tmux pane option via `TMUX_PANE` | `@yt_task` = `tasks 0/2 > one`. |
| `bin/ytstack-status` timing in this repo | 0.24 to 0.39 s wall time on this machine (docs say "well under a tenth of a second"; other sessions were running). |

Not tested: fullscreen renderer, Desktop and VS Code, the `Pane` site, OSC 7501 terminals, iTerm2 or WezTerm user variables, very small terminals with a multi-line mod band plus a multi-line status line.

## Herdr (added 2026-11-15, the maintainer runs the agent CLIs in herdr, not tmux)

The maintainer runs the coding agent CLIs inside herdr 0.9.5 (a terminal workspace manager for agents), so tmux is out. Herdr has its own per-pane surface for exactly this:

- `herdr pane report-metadata <pane> --source <id> [--title TEXT] [--token NAME=VALUE] [--state-label STATUS=TEXT] [--display-agent TEXT] [--ttl-ms N] [--seq N]`: display-only metadata on a pane, from any process in it. Every pane gets `HERDR_PANE_ID` (and `HERDR_ENV=1`), so a hook or status line script in the agent's pane can address its own pane without lookups.
- Tested on this session's pane: `report-metadata "$HERDR_PANE_ID" --source ytstack-probe --title "ytstack: ..." --token task="2/5 probe" --ttl-ms 120000` returned no error, and `herdr pane get` then showed `"title": "ytstack: ..."` and `"tokens": {"task": "2/5 probe"}` next to `agent_status` and the agent session id. Where the herdr TUI renders `title` and `tokens` (pane header, sidebar, agent list) was not checked visually: unverified.
- Herdr already knows the agent and its session: its own `claude`, `codex`, `kimi` and `opencode` integrations (`herdr integration status`) report `agent_status` (idle, working, blocked, done) per pane. The todo item would sit next to that state, across all panes and in herdr's clients (the installed Ovis plugin shows every agent pane in a browser or phone).
- `--source` scopes the metadata to its writer, so ytstack's title does not fight herdr's own agent reports; `--ttl-ms` lets a stale title expire if a session dies; `--seq` orders concurrent writes.

This replaces the tmux option. A ytstack hook can, per host:

- Claude Code: a PostToolUse hook on the task tools (`TaskCreate`, `TaskUpdate`, `TodoWrite`) reads the session's task files (see above) and calls `report-metadata --title "<in-progress subject>" --token tasks=<done>/<total>`; it does nothing unless `HERDR_ENV=1` and `herdr` is on PATH. A plugin can ship such a hook itself (no settings.json edit), unlike the status line. Still needs `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` on current models.
- Codex: the `update_plan` call is visible to a PostToolUse hook (unverified for the plan payload); the same call with the plan's in-progress step.
- Kimi: unverified; the integration hook of herdr exists, a ytstack equivalent would need Kimi's hook payload.

## Options for ytstack

Ranked by value per effort. "User wires" is what ytstack cannot do itself. With herdr in use, option 0 below comes first.

0. **Herdr pane metadata from a ytstack hook** (new). A `hooks/herdr-status` PostToolUse hook (opt-in, e.g. `herdr_status=on` in `~/.ytstack/config` like `pr_watch`) that writes the current task and n/m to the agent's own herdr pane. Effort: small (one hook, one reader of the task files shared with `ytstack-status`, tests with a stand-in `herdr`). User wires: nothing beyond the opt-in and, on current Claude models, `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`. Open: where herdr renders `title`/`tokens`, and whether a herdr config can pin them.

### 1. `ytstack-status --tasks`: a task segment in the existing script (small)

Add an opt-in task reader to `bin/ytstack-status`: read `session_id` from stdin, find the directory (`CLAUDE_CODE_TASK_LIST_ID`, then `session-<8>`, then the full id, under `${CLAUDE_CONFIG_DIR:-~/.claude}/tasks`), print `tasks 3/7 > <in_progress subject>` as a segment, or with `--lines N` up to N rows (`[x]`, `[>]`, `[ ]`). No task files: no output, so the existing project segment is unchanged.

- Ships: the reader, tests with fixture directories, `docs/statusline.md` update with the multi-line example and the `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` note.
- User wires: the status line (already documented) and, on current models, `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` in `env` of their settings or shell. Optional `refreshInterval: 2` so the line stays current while subagents work.
- Risks: the on-disk layout is undocumented, so the reader must fail quietly and the suite should pin the observed shapes. Parsing JSON in bash needs `jq` or a small parser; `yt_read_stdin` today reads only `cwd`.

### 2. A ytstack mod for the band above the prompt (medium)

Add `hooks/register.js` to the Claude Code plugin: on `session.start` start a 2-second timer that reads the task files (same rule as option 1) and the `.ytstack/STATE.md` pointer, and draw at most `maxRows` rows in `AbovePrompt`: the in-progress task, `n/m` done, and the ytstack task pointer. Return `next(e)` when there is nothing to show.

- Ships: everything. No user settings. This is the only Claude Code surface ytstack can fill on its own.
- User wires: nothing, except `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` on current models.
- Costs: a JavaScript module in a bash-first repo, a new test path (`claude plugin validate`, mod tests per [Test a mod](https://code.claude.com/docs/en/plugins/mods/test)), and a decision entry because `hooks/hooks.json` would gain a `modules` key. Check first how Codex and Kimi treat a `modules` key in a shared `hooks.json` (unverified). Duplicates the built-in list when the user also expands Ctrl+T, so the mod should show one compact row by default.

### 3. tmux recipe for the operator view (small, docs only)

Document in `docs/statusline.md`: the status line script writes `@yt_task` to `TMUX_PANE`, and `pane-border-status top` with `pane-border-format` shows every session's current task on its pane border; `status 2` adds a line for the focused pane. This is the only option that shows **all** sessions at once, which is the actual operator need.

- Ships: the recipe and, inside option 1, a `--tmux` flag that sets the pane option.
- User wires: `~/.tmux.conf` and the status line.

### 4. Title setter hook (small, weak)

A `PostToolUse` hook on `TaskCreate|TaskUpdate` that returns `terminalSequence` with OSC 2. It ships in `hooks/hooks.json`, but Claude Code's own title overwrites it unless the user sets `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`, which costs them the generated session title. Not recommended as a default. An alternative is `sessionTitle` from `UserPromptSubmit`, but it only changes at prompt time and replaces a name the user set with `/rename`.

### 5. Cross-host fallback

- **Codex**: document `task-progress` for `[tui] status_line` and `[tui] terminal_title` in `docs/codex.md`. The user adds it (their wrapper already sets `status_line`). That gives `Tasks n/m` and nothing more; the step text cannot be shown, because there is no command item.
- **Kimi**: the option 1 reader works if it learns Kimi's session layout (`sessionId` plus `session_index.jsonl`), but only one line is shown. Needs a live check of where `SetTodoList` state is stored first.
- **Everywhere**: the ytstack pointer (`M###/S##/T##` plus the slice count) that `ytstack-status` prints today is the host-neutral "what is this session doing" signal. The tmux pane option (option 3) works for any host whose status line or hook can run a command.

### What not to do

- Do not edit `~/.claude/settings.json` from a skill or hook (DECISIONS 2026-11-11; the status line stays user-owned).
- Do not keep a second, ytstack-owned to-do list just to have something to show. The host list is the agent's working list; `.ytstack/STATE.md` holds the plan pointer. A reader of both is enough.

## Relation to meinKontext (context-mcp)

meinKontext has no plan for a session to-do tool of its own. `.ytstack/USE-CASES.md` §12 "A task list for agent sessions" (status: nice to have) describes a `TodoWrite`-like list for the operator's tasks of the current session, "including the setup of a status line showing the current task and the overall progress". Its mapping: tasks are records of the existing Tasks plugin (MCP, for example `task_command`), a skill over that plugin may cover the list without a plugin of its own, and "the status line is client configuration and lives with the client, not in meinKontext". Coverage: v2 has the Tasks plugin over MCP; AV-08 has nothing; a new plugin would need the operator's approval. So the split is clean: meinKontext can be the durable, shared store of tasks across sessions and people; the sticky display belongs to the client and is what this note proposes for ytstack. A later bridge could let the ytstack reader also show a meinKontext task list by id, but that needs a network call, which `ytstack-status` rules out today. `packages/plugin-client/src/native-codex.ts` already skips Codex `todo_list` items when it imports native Codex sessions.

## Open questions

1. Should ytstack recommend `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` at all? Anthropic turned the tools off for newer models on purpose (context cost, the model tracks work without them). Without them there is no list to show, and a ytstack pointer (`M###/S##/T##` plus the slice count) is the only "what is this session doing" signal.
2. Is a JavaScript mod acceptable in ytstack, or does the band wait until a host-neutral way exists? Needs a DECISIONS entry either way.
3. How stable is `~/.claude/tasks/session-<8>/`? It is not documented. Ask upstream for a documented field (`tasks` or `task_list_id` in the status line JSON) and file the request.
4. Should the operator view (all sessions at once) be a ytstack concern or a terminal recipe only? Option 3 is cheap; a richer view would be a separate tool, outside the plugin.
5. Unverified: what Desktop, VS Code and fullscreen rendering do with a tall status line and with the mod band.
