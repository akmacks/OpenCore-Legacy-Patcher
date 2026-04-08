# Home Directory Cleanup Plan
## Audited: 2026-03-29 | Session 10–11
## Status: COMPLETE ✅

---

## What was done (2026-03-29)

### ✅ Deleted (no archive needed — junk)
- `~/default.profraw` — LLVM build artifact (user deleted)
- `~/getting-started/` — Docker tutorial from 2021 (user deleted)
- `~/myenv/` — orphan Python venv (user deleted)
- `~/vw/` — unknown 2018 hash files (user deleted)
- `~/myproject/` — Claude API test script (user deleted)

### ✅ Archived then deleted
Archives saved to: `~/Library/Application Support/BridgeRestore/archives/`
- `legacy-home-scripts-20260329-112351.zip` (88 KB)
  - `~/bridge-restore/` — early v0 scripts
  - `~/bridge-restore-project/` — session 5 project folder
  - `~/fix-bridge.sh` — 5-line bridge stub
  - `~/scripts/` — mini-launchd artifacts + archived old scripts
- `legacy-openclaw-logs-20260329-112355.zip` (12 KB)
  - `~/logs/openclaw/` — old diagnostic outputs
  - `~/logs/scripts/` — empty directory

### ✅ Moved: ~/projects/ → ~/dev/projects/ (2026-03-29)
- New canonical dev root: `~/dev/`
- Symlink created: `~/projects` → `~/dev/projects` (backward compat)
- Path updated in 31 files (sed bulk replacement)
- `.zshrc` updated
- All aliases updated and verified loading cleanly

### ✅ Kept in place (system/active)
- `~/dev/` — new dev root
- `~/Developer/` — reserved for Apple/Xcode formal projects
- `~/logs/` — active runtime logs (bridge-restore, tunnel-mini etc.)
- `~/.config/bridge-restore/` — active app config
- `~/.claude/` — Claude Code CLI
- `~/.agents/` — AI skills (Microsoft Foundry etc.)
- `~/.mono/` — Mono/.NET registry
- `~/go/` — Go toolchain package cache
- `~/electrum/` — Bitcoin wallet source (user keeping)
- `~/Documents/Github/` — GitHub repos (OCLP etc.)

---

## Current canonical structure

```
~/ (home)
├── dev/                        ← Development root
│   └── projects/               ← All projects
│       ├── apps/
│       │   └── app_macOS-Intel_BridgeRestore/  ← Bridge Restore (ACTIVE)
│       └── logs/
├── Developer/                  ← Apple/Xcode only
├── Documents/Github/           ← GitHub repos
├── logs/                       ← Runtime logs
└── ~/projects → ~/dev/projects (symlink, backward compat)
```

---
*Cleanup complete: 2026-03-29 | Session 11*
