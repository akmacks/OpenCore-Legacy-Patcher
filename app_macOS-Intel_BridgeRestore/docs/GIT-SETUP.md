# Git Setup & GitHub Push Instructions
## app_macOS-Intel_BridgeRestore | 2026-03-28

---

## Step 1 — Initialise Local Repo

```bash
cd ~/dev/projects/apps/app_macOS-Intel_BridgeRestore
git init
git add .
git status          # verify 18 files staged, config/ and logs excluded by .gitignore
```

## Step 2 — First Commit

```bash
git commit -m "feat: v1.0.0-alpha — Bridge Restore App bash engine

- Role-aware architecture: gateway (MBP) + client (Mini) via hardware UUID
- First-launch Setup Wizard (AppleScript GUI)
- Preferences: Hosts, OSI Diagnostic Layers, Watchdog settings
- OSI L1-L7 diagnostic engine, individually toggleable
- IS toggle: defaults write + background dialog auto-clicker
- TB severance: 4 software methods (no cable reseat needed)
- Embedded watchdog: smart alerts, action menu after 10 failures
- Ollama AI fallback: local-first (llama3.2:3b, gpt-oss:20b)
- launchd plists for mini deployment
- Machine UUID identity guards on all scripts
- sudoers NOPASSWD — no more osascript password prompts"
```

## Step 3 — Create GitHub Repo and Push

```bash
# Using GitHub CLI (gh is installed)
gh repo create app_macOS-Intel_BridgeRestore \
  --private \
  --description "Thunderbolt Bridge connectivity suite for macOS — role-aware restore, AI-assisted diagnostics" \
  --source=. \
  --push

# Verify
gh repo view app_macOS-Intel_BridgeRestore
```

## Step 4 — Open in VS Code

```bash
code ~/dev/projects/apps/app_macOS-Intel_BridgeRestore
```

Recommended VS Code extensions for this project:
- Shell Script (bashIDE) — syntax highlighting for .sh files
- ShellCheck — linting for bash scripts
- Plist Editor — for .plist launchd files
- GitLens — enhanced git history

## Step 5 — Open in Xcode (for SwiftUI wrapper phase)

```bash
# Create new Xcode project in the repo directory
open ~/dev/projects/apps/app_macOS-Intel_BridgeRestore
# File → New → Project → macOS → App
# Name: BridgeRestore
# Bundle ID: com.akmacks.bridge-restore
# Store in: ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/
```

Xcode project structure to create:
```
BridgeRestore.xcodeproj
BridgeRestore/
├── BridgeRestoreApp.swift
├── AppDelegate.swift
├── MenuBarController.swift
├── Views/
├── Models/
├── Services/
└── Resources/
```

The Swift app calls the existing bash engine via `Process()`:
```swift
// Example: ShellService.swift
func runDiagnostics() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [
        "/usr/local/bin/bridge-restore-app", "--diag"
    ]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}
```

## Step 6 — Deploy to Mini (once tunnel is up)

```bash
# From MBP after tunnel-mini succeeds
bash ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/scripts/install-on-mini.sh
```

---

## Ongoing Git Workflow

```bash
# After each dev session
git add -A
git commit -m "type: short description"
git push

# Commit types: feat, fix, refactor, docs, test, chore
```

---
*Generated: 2026-03-28 | Ready for GitHub Desktop + VS Code + Xcode*
