#!/usr/bin/env swift
// bridge-restore-panel.swift — Phase 1b persistent NSPanel
// Run: swift /path/to/bridge-restore-panel.swift
// VERSION: v1.0.6 (Build 26A06)

import Cocoa
import Foundation

let SCRIPTS = ProcessInfo.processInfo.environment["BR_SCRIPTS"]
    ?? "/Users/akmacks/dev/projects/apps/app_macOS-Intel_BridgeRestore/scripts"
let STATUS_CMD  = "bash \(SCRIPTS)/status-check.sh"
let REFRESH_S: TimeInterval = 15
let W: CGFloat = 840; let H: CGFloat = 520
let LW: CGFloat = 360; let PAD: CGFloat = 12

// ── Palette ───────────────────────────────────────────────────────
func rgb(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat) -> NSColor {
    NSColor(red: r/255, green: g/255, blue: b/255, alpha: 1)
}
let cBg     = rgb(28,28,30);    let cPanel  = rgb(44,44,46)
let cGreen  = rgb(48,209,88);   let cYellow = rgb(255,214,10)
let cRed    = rgb(255,69,58);   let cGrey   = rgb(142,142,147)
let cBlue   = rgb(10,132,255);  let cWhite  = rgb(255,255,255)
let cDim    = rgb(180,180,185); let cBorder = rgb(72,72,74)
let cOutBg  = rgb(20,20,22)

// ── Shell helper ──────────────────────────────────────────────────
func shell(_ cmd: String) -> String {
    let t = Process(); let p = Pipe()
    t.launchPath = "/bin/zsh"; t.arguments = ["-c", cmd]
    t.standardOutput = p; t.standardError = Pipe()
    t.launch(); t.waitUntilExit()
    return String(data: p.fileHandleForReading.readDataToEndOfFile(),
                  encoding: .utf8) ?? ""
}

// ── Parse status JSON ─────────────────────────────────────────────
struct Check: Decodable { let status, value, detail: String }
struct Summary: Decodable { let all_green: Int; let red_count: Int; let grey_count: Int }
struct Status: Decodable {
    let role, friendly, model: String
    let checks: [String: Check]
    let summary: Summary
}
func getStatus() -> Status? {
    guard let d = shell(STATUS_CMD).data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(Status.self, from: d)
}

// ── UI helpers ────────────────────────────────────────────────────
func makeLabel(_ s: String, _ f: NSFont, _ c: NSColor) -> NSTextField {
    let t = NSTextField(labelWithString: s)
    t.font = f; t.textColor = c
    t.backgroundColor = .clear; t.isSelectable = false
    return t
}
func dotChar(_ s: String) -> String {
    switch s { case "green": return "●"; case "yellow": return "◐"
               case "red":   return "●"; default: return "○" }
}
func dotColor(_ s: String) -> NSColor {
    switch s { case "green": return cGreen; case "yellow": return cYellow
               case "red":   return cRed;   default: return cGrey }
}

// ── Row order ─────────────────────────────────────────────────────
let ROW_KEYS = ["host_ip","bridge","peer_ip","internet","tunnel","controlmaster","is"]
let ROW_LABELS = ["Host IP","Bridge","Client IP","Internet","Tunnel","SSH","IS"]

// ── App Delegate ──────────────────────────────────────────────────
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var dotFields  = [String: NSTextField]()
    var valFields  = [String: NSTextField]()
    var outputView: NSTextView!
    var scrollView: NSScrollView!

    func applicationDidFinishLaunching(_ n: Notification) {
        buildPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(withTimeInterval: REFRESH_S, repeats: true) { _ in
            if let s = getStatus() { self.refreshStatus(s) }
        }
    }

    func buildPanel() {
        let style: NSWindow.StyleMask = [.titled,.closable,.miniaturizable,
                                         .resizable,.utilityWindow]
        panel = NSPanel(contentRect: NSRect(x:200,y:200,width:W,height:H),
                        styleMask: style,
                        backing: .buffered, defer: false)
        panel.title = "Bridge Restore"
        panel.backgroundColor = cBg
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let cv = panel.contentView!
        buildLeft(cv)
        buildDivider(cv)
        buildOutputPane(cv)
        populateWelcome()
    }

    func buildLeft(_ parent: NSView) {
        let bg = NSView(frame: NSRect(x:0,y:0,width:LW,height:H))
        bg.wantsLayer = true; bg.layer?.backgroundColor = cPanel.cgColor
        parent.addSubview(bg)

        // Header
        let mono12 = NSFont.monospacedSystemFont(ofSize:12, weight:.regular)
        let sys11  = NSFont.systemFont(ofSize:11)
        let sysBold14 = NSFont.boldSystemFont(ofSize:14)
        let sys12  = NSFont.systemFont(ofSize:12)
        let mono11 = NSFont.monospacedSystemFont(ofSize:11, weight:.regular)

        let hdr = makeLabel("BRIDGE RESTORE", sysBold14, cWhite)
        hdr.frame = NSRect(x:PAD, y:H-36, width:LW-PAD*2, height:22)
        bg.addSubview(hdr)

        let st = getStatus()
        let roleStr = st.map { "\($0.role): \($0.friendly)  ·  \($0.model)" } ?? "checking…"
        let sub = makeLabel(roleStr, sys11, cGrey)
        sub.frame = NSRect(x:PAD, y:H-56, width:LW-PAD*2, height:16)
        bg.addSubview(sub)

        // Separator
        let sep = NSBox(frame: NSRect(x:PAD,y:H-68,width:LW-PAD*2,height:1))
        sep.boxType = .separator; bg.addSubview(sep)

        // Status rows
        var y = H - 92
        for (i, key) in ROW_KEYS.enumerated() {
            let chk = st?.checks[key]
            let dot = makeLabel(dotChar(chk?.status ?? "grey"), mono12,
                                dotColor(chk?.status ?? "grey"))
            dot.frame = NSRect(x:PAD, y:y, width:18, height:18)
            bg.addSubview(dot); dotFields[key] = dot

            let lbl = makeLabel(ROW_LABELS[i], sys11, cDim)
            lbl.frame = NSRect(x:PAD+22, y:y, width:90, height:16)
            bg.addSubview(lbl)

            let val = makeLabel(chk?.value ?? "…", mono11, cWhite)
            val.frame = NSRect(x:PAD+116, y:y, width:LW-PAD-122, height:16)
            bg.addSubview(val); valFields[key] = val
            y -= 24
        }

        // Separator above buttons
        let sep2 = NSBox(frame: NSRect(x:PAD,y:168,width:LW-PAD*2,height:1))
        sep2.boxType = .separator; bg.addSubview(sep2)

        // Buttons
        let BW = (LW - PAD*3) / 2
        let btns: [(String, String)] = [
            ("tunnel-mini",  "tunnel-mini"),
            ("tunnel-pro",   "tunnel-pro"),
            ("Status",       STATUS_CMD),
            ("Diagnostics",  "\(SCRIPTS)/bridge-restore-app.sh --diag"),
            ("Console",      "log show --last 10m --predicate 'messageType == fault OR messageType == error' --style compact 2>/dev/null | grep -v '^Timestamp' | tail -40 || echo 'No errors in last 10m'"),
            ("Health",       "ps -axro %cpu,%mem,pid,user,comm | head -12; echo '---'; vm_stat | grep -E 'free|active|inactive|wired'; echo '---'; uptime"),
            ("Rescue Bot",   "rescue-bot diagnose"),
            ("Refresh",      STATUS_CMD)
        ]
        btns.enumerated().forEach { (i, btn) in
            let col = i % 2; let row = i / 2
            let bx = PAD + CGFloat(col)*(BW+PAD)
            let by = CGFloat(148 - row*36)
            let b = NSButton(frame: NSRect(x:bx,y:by,width:BW,height:28))
            b.isBordered = false
            b.wantsLayer = true
            b.layer?.backgroundColor = NSColor(red:58/255,green:58/255,blue:60/255,alpha:1).cgColor
            b.layer?.cornerRadius = 6
            b.layer?.borderWidth = 0.5
            b.layer?.borderColor = NSColor(red:100/255,green:100/255,blue:105/255,alpha:1).cgColor
            b.attributedTitle = NSAttributedString(string: btn.0, attributes: [
                .font: sys12,
                .foregroundColor: NSColor.white
            ])
            b.target = self
            b.action = #selector(buttonAction(_:))
            b.identifier = NSUserInterfaceItemIdentifier(btn.1)
            bg.addSubview(b)
        }

        // IS Settings shortcut
        let isBtn = NSButton(frame: NSRect(x:PAD,y:10,width:LW-PAD*2,height:24))
        isBtn.isBordered = false
        isBtn.wantsLayer = true
        isBtn.layer?.backgroundColor = NSColor(red:80/255,green:50/255,blue:10/255,alpha:1).cgColor
        isBtn.layer?.cornerRadius = 6
        isBtn.layer?.borderWidth = 0.5
        isBtn.layer?.borderColor = cYellow.cgColor
        isBtn.attributedTitle = NSAttributedString(string: "⚠  Open Sharing Settings", attributes: [
            .font: sys11,
            .foregroundColor: cYellow
        ])
        isBtn.target = self; isBtn.action = #selector(openSharing)
        bg.addSubview(isBtn)
    }

    func buildDivider(_ cv: NSView) {
        let d = NSBox(frame: NSRect(x:LW,y:0,width:1,height:H))
        d.boxType = .separator; cv.addSubview(d)
    }

    func buildOutputPane(_ cv: NSView) {
        scrollView = NSScrollView(frame: NSRect(x:LW+1,y:0,width:W-LW-1,height:H))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = cOutBg

        outputView = NSTextView(frame: NSRect(x:0,y:0,width:W-LW-1,height:H))
        outputView.backgroundColor = cOutBg
        outputView.textColor = cWhite
        outputView.font = NSFont.monospacedSystemFont(ofSize:11, weight:.regular)
        outputView.isEditable = false
        outputView.isRichText = true
        outputView.isAutomaticQuoteSubstitutionEnabled = false

        scrollView.documentView = outputView
        cv.addSubview(scrollView)
    }

    func appendOutput(_ text: String, _ color: NSColor = .white) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize:11, weight:.regular),
            .foregroundColor: color
        ]
        let astr = NSAttributedString(string: text + "\n", attributes: attrs)
        outputView.textStorage?.append(astr)
        outputView.scrollRangeToVisible(NSRange(location: outputView.string.count, length: 0))
    }

    func populateWelcome() {
        appendOutput("Bridge Restore v1.0.6 (Build 26A06)", cBlue)
        appendOutput("─────────────────────────────────────────", cBorder)
        if let s = getStatus() {
            let msg: String
            let col: NSColor
            if s.summary.red_count > 0 {
                msg = "⚠️  \(s.summary.red_count) check(s) need attention"
                col = cYellow
            } else if s.summary.grey_count > 0 {
                let active = 7 - s.summary.grey_count
                msg = "✅ \(active)/7 active checks green  ·  \(s.summary.grey_count) N/A for this role"
                col = cGreen
            } else {
                msg = "✅ All systems green"
                col = cGreen
            }
            appendOutput(msg, col)
        }
        appendOutput("Press a button to run a command.", cDim)
        appendOutput("Output streams here. Refreshes every \(Int(REFRESH_S))s.", cDim)
    }

    func refreshStatus(_ s: Status) {
        DispatchQueue.main.async {
            for key in ROW_KEYS {
                guard let chk = s.checks[key] else { continue }
                self.dotFields[key]?.textColor = dotColor(chk.status)
                self.dotFields[key]?.stringValue = dotChar(chk.status)
                self.valFields[key]?.stringValue = chk.value
            }
        }
    }

    @objc func buttonAction(_ sender: NSButton) {
        let cmd = sender.identifier?.rawValue ?? ""
        appendOutput("\n▶ \(sender.title)", cBlue)
        appendOutput("  $ \(cmd)", cDim)
        DispatchQueue.global(qos: .userInitiated).async {
            let out = shell(cmd)
            DispatchQueue.main.async {
                out.components(separatedBy: "\n").forEach { line in
                    let col: NSColor = line.contains("✅") || line.contains("OK") ? cGreen :
                                       line.contains("⚠️") || line.contains("WARN") ? cYellow :
                                       line.contains("❌") || line.contains("FAIL") ? cRed : cWhite
                    self.appendOutput(line, col)
                }
                self.appendOutput("─────────────────────────────────────", cBorder)
                if let s = getStatus() { self.refreshStatus(s) }
            }
        }
    }

    @objc func openSharing() {
        NSWorkspace.shared.open(
            URL(string:"x-apple.systempreferences:com.apple.preferences.sharing?Internet_Sharing")!)
        appendOutput("Opened System Settings → Sharing", cYellow)
    }
}

// ── Entry point ───────────────────────────────────────────────────
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
