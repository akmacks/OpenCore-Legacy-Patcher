#!/usr/bin/env osascript -l JavaScript
// ╔══════════════════════════════════════════════════════════════════╗
// ║  bridge-restore-panel.js — Phase 1b persistent NSPanel          ║
// ║  JXA + ObjC bridge: floating dashboard, never disappears        ║
// ║  VERSION: v1.0.6 (Build 26A06)                            ║
// ╚══════════════════════════════════════════════════════════════════╝

ObjC.import('AppKit')
ObjC.import('Foundation')

const SCRIPTS = '/Users/akmacks/dev/projects/apps/app_macOS-Intel_BridgeRestore/scripts'
const STATUS_CMD  = `bash ${SCRIPTS}/status-check.sh`
const REFRESH_S   = 15
const W = 820; const H = 520
const LEFT_W = 360; const PAD = 12

// ── Colours ────────────────────────────────────────────────────────
function rgb(r,g,b) {
  return $.NSColor.colorWithRedGreenBlueAlpha(r/255, g/255, b/255, 1)
}
const C = {
  bg:      rgb(28,  28,  30),
  panel:   rgb(44,  44,  46),
  border:  rgb(72,  72,  74),
  green:   rgb(48, 209,  88),
  yellow:  rgb(255,214,  10),
  red:     rgb(255,  69,  58),
  grey:    rgb(142, 142, 147),
  blue:    rgb(10,  132, 255),
  white:   rgb(255, 255, 255),
  dim:     rgb(180, 180, 185),
  btnBg:   rgb(58,  58,  60),
  outBg:   rgb(20,  20,  22),
}

// ── Helper: make NSFont ────────────────────────────────────────────
const mono  = (sz) => $.NSFont.fontWithNameSize('Menlo', sz)
const sans  = (sz) => $.NSFont.fontWithNameSize('SF Pro Display', sz) ||
                      $.NSFont.systemFontOfSize(sz)
const sansBold = (sz) => $.NSFont.boldSystemFontOfSize(sz)

// ── Helper: NSTextField label ──────────────────────────────────────
function label(text, x, y, w, h, font, color) {
  const f = $.NSTextField.alloc.initWithFrame($.NSMakeRect(x, y, w, h))
  f.stringValue = text
  f.font = font
  f.textColor = color
  f.backgroundColor = $.NSColor.clearColor
  f.bezeled = false
  f.editable = false
  f.selectable = false
  return f
}

// ── Helper: run shell command, return stdout ───────────────────────
function shell(cmd) {
  const t = $.NSTask.alloc.init
  t.launchPath = '/bin/zsh'
  t.arguments  = ['-c', cmd]
  const p = $.NSPipe.pipe
  t.standardOutput = p
  t.standardError  = $.NSPipe.pipe
  t.launch; t.waitUntilExit
  const d = p.fileHandleForReading.readDataToEndOfFile
  return $.NSString.alloc.initWithDataEncoding(d, $.NSUTF8StringEncoding).js
}

// ── Parse status JSON ──────────────────────────────────────────────
function getStatus() {
  try {
    const raw = shell(STATUS_CMD)
    return JSON.parse(raw)
  } catch(e) {
    return null
  }
}

// ── Colour for status string ───────────────────────────────────────
function statusColor(s) {
  if (s === 'green')  return C.green
  if (s === 'yellow') return C.yellow
  if (s === 'red')    return C.red
  return C.grey
}

// ── Dot character for status ───────────────────────────────────────
function dot(s) {
  if (s === 'green')  return '●'
  if (s === 'yellow') return '◐'
  if (s === 'red')    return '●'
  return '○'
}

// ── Build status rows in the left panel ───────────────────────────
let dotFields = {}   // key → NSTextField (dot)
let valFields = {}   // key → NSTextField (value)

function buildStatusRows(parent, status) {
  const rows = [
    { key: 'host_ip',       label: 'Host IP' },
    { key: 'bridge',        label: 'Bridge' },
    { key: 'peer_ip',       label: 'Client IP' },
    { key: 'internet',      label: 'Internet' },
    { key: 'tunnel',        label: 'Tunnel' },
    { key: 'controlmaster', label: 'SSH' },
    { key: 'is',            label: 'IS' },
  ]
  let y = H - 160
  rows.forEach(r => {
    const chk = status ? status.checks[r.key] : null
    const st  = chk ? chk.status : 'grey'
    const val = chk ? chk.value  : '…'

    // dot
    const df = label(dot(st), PAD, y, 20, 20, mono(14), statusColor(st))
    parent.addSubview(df); dotFields[r.key] = df

    // row label
    parent.addSubview(label(r.label, PAD+22, y, 90, 18, sans(12), C.dim))

    // value
    const vf = label(val, PAD+114, y, LEFT_W-PAD-120, 18, mono(12), C.white)
    parent.addSubview(vf); valFields[r.key] = vf

    y -= 24
  })
}

// ── Update status rows (called on refresh) ────────────────────────
function refreshStatus(status) {
  if (!status) return
  Object.keys(dotFields).forEach(k => {
    const chk = status.checks[k]
    if (!chk) return
    dotFields[k].textColor = statusColor(chk.status)
    dotFields[k].stringValue = dot(chk.status)
    valFields[k].stringValue = chk.value
  })
}

// ── NSButton helper ────────────────────────────────────────────────
function makeButton(title, x, y, w, h, action) {
  const b = $.NSButton.alloc.initWithFrame($.NSMakeRect(x, y, w, h))
  b.title = title
  b.bezelStyle = $.NSBezelStyleRounded
  b.font = sans(12)
  b.target = action
  b.action = 'callAsFunction'
  return b
}

// ── Output NSTextView (right panel) ───────────────────────────────
let outputTV

function buildOutputPane(parent) {
  const scroll = $.NSScrollView.alloc.initWithFrame(
    $.NSMakeRect(LEFT_W+1, 0, W-LEFT_W-1, H))
  scroll.hasVerticalScroller = true
  scroll.autohidesScrollers = true
  scroll.backgroundColor = C.outBg

  outputTV = $.NSTextView.alloc.initWithFrame(
    $.NSMakeRect(0, 0, W-LEFT_W-1, H))
  outputTV.backgroundColor = C.outBg
  outputTV.textColor = C.white
  outputTV.font = mono(11)
  outputTV.editable = false
  outputTV.richText = false
  outputTV.automaticQuoteSubstitutionEnabled = false

  scroll.documentView = outputTV
  parent.addSubview(scroll)
}

// ── Append coloured text to output pane ───────────────────────────
function appendOutput(text, color) {
  const col = color || C.white
  const attrs = $.NSMutableDictionary.alloc.init
  attrs.setObjectForKey(mono(11), $.NSFontAttributeName)
  attrs.setObjectForKey(col, $.NSForegroundColorAttributeName)
  const astr = $.NSAttributedString.alloc.initWithStringAttributes(text+'\n', attrs)
  outputTV.textStorage.appendAttributedString(astr)
  outputTV.scrollRangeToVisible(
    $.NSMakeRange(outputTV.string.length, 0))
}

// ── Run command, stream to output pane ────────────────────────────
function runCmd(label, cmd) {
  appendOutput(`\n▶ ${label}`, C.blue)
  appendOutput(`  $ ${cmd}`, C.dim)
  const out = shell(cmd)
  out.split('\n').forEach(line => {
    const col = line.includes('✅') || line.includes('OK') ? C.green :
                line.includes('⚠️') || line.includes('WARN') ? C.yellow :
                line.includes('❌') || line.includes('FAIL') ? C.red : C.white
    appendOutput(line, col)
  })
  appendOutput('─────────────────────────────────────', C.border)
}

// ══════════════════════════════════════════════════════════════════
// MAIN — build and show the panel
// ══════════════════════════════════════════════════════════════════

const app = $.NSApplication.sharedApplication
app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)

// ── Create the NSPanel ─────────────────────────────────────────────
const styleMask = $.NSWindowStyleMaskTitled
  | $.NSWindowStyleMaskClosable
  | $.NSWindowStyleMaskMiniaturizable
  | $.NSWindowStyleMaskResizable
  | $.NSWindowStyleMaskUtilityWindow

const panel = $.NSPanel.alloc.initWithContentRectStyleMaskBackingDefer(
  $.NSMakeRect(200, 200, W, H), styleMask,
  $.NSBackingStoreBuffered, false)
panel.title = 'Bridge Restore'
panel.backgroundColor = C.bg
panel.level = $.NSFloatingWindowLevel
panel.floatingPanel = true
panel.becomesKeyOnlyIfNeeded = true
panel.hidesOnDeactivate = false

const content = panel.contentView

// ── Left panel background ──────────────────────────────────────────
const leftBg = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, LEFT_W, H))
leftBg.wantsLayer = true
leftBg.layer.backgroundColor = C.panel.CGColor
content.addSubview(leftBg)

// ── Vertical divider ──────────────────────────────────────────────
const div = $.NSBox.alloc.initWithFrame($.NSMakeRect(LEFT_W, 0, 1, H))
div.boxType = $.NSBoxSeparator
content.addSubview(div)

// ── Header: role + friendly name ──────────────────────────────────
const status0 = getStatus()
const role     = status0 ? status0.role     : '…'
const friendly = status0 ? status0.friendly : '…'
const model    = status0 ? status0.model    : '…'

leftBg.addSubview(label('BRIDGE RESTORE', PAD, H-36, LEFT_W-PAD*2, 22,
  sansBold(15), C.white))
leftBg.addSubview(label(`${role}: ${friendly}  ·  ${model}`, PAD, H-56,
  LEFT_W-PAD*2, 16, sans(11), C.grey))

// ── Separator under header ────────────────────────────────────────
const sep1 = $.NSBox.alloc.initWithFrame($.NSMakeRect(PAD, H-70, LEFT_W-PAD*2, 1))
sep1.boxType = $.NSBoxSeparator; leftBg.addSubview(sep1)

// ── Status rows ────────────────────────────────────────────────────
buildStatusRows(leftBg, status0)

// ── Separator above buttons ────────────────────────────────────────
const sep2 = $.NSBox.alloc.initWithFrame($.NSMakeRect(PAD, 170, LEFT_W-PAD*2, 1))
sep2.boxType = $.NSBoxSeparator; leftBg.addSubview(sep2)

// ── Buttons ────────────────────────────────────────────────────────
const BW = (LEFT_W - PAD*3) / 2
const buttons = [
  { label: 'tunnel-mini',  cmd: 'tunnel-mini' },
  { label: 'tunnel-pro',   cmd: 'tunnel-pro'  },
  { label: 'Status',       cmd: `bash ${SCRIPTS}/status-check.sh` },
  { label: 'Diagnostics',  cmd: `bash ${SCRIPTS}/bridge-restore-app.sh --diag` },
  { label: 'Rescue Bot',   cmd: 'rescue-bot diagnose' },
  { label: 'Refresh',      cmd: STATUS_CMD },
]

const btnRows = [[buttons[0],buttons[1]],[buttons[2],buttons[3]],[buttons[4],buttons[5]]]
btnRows.forEach((row, ri) => {
  row.forEach((btn, ci) => {
    const bx = PAD + ci*(BW+PAD)
    const by = 130 - ri*40
    const b = makeButton(btn.label, bx, by, BW, 30, () => {
      appendOutput('', C.dim)
      runCmd(btn.label, btn.cmd)
      if (btn.label === 'Refresh' || btn.label === 'Status') {
        const s = getStatus()
        if (s) refreshStatus(s)
      }
    })
    leftBg.addSubview(b)
  })
})

// ── IS restart helper button ───────────────────────────────────────
const isBtn = makeButton('⚠ Open Sharing Settings', PAD, 18, LEFT_W-PAD*2, 22, () => {
  shell(`open 'x-apple.systempreferences:com.apple.preferences.sharing?Internet_Sharing'`)
  appendOutput('Opened System Settings → Sharing', C.yellow)
})
isBtn.font = sans(11)
leftBg.addSubview(isBtn)

// ── Right output pane ──────────────────────────────────────────────
buildOutputPane(content)

// ── Welcome message in output ─────────────────────────────────────
appendOutput('Bridge Restore v1.0.6 (Build 26A06)', C.blue)
appendOutput('─────────────────────────────────────────', C.border)
if (status0) {
  const s = status0.summary
  const msg = s.red_count === 0
    ? '✅ All systems green'
    : `⚠️  ${s.red_count} check(s) need attention`
  appendOutput(msg, s.red_count === 0 ? C.green : C.yellow)
}
appendOutput('Press a button to run a command. Output appears here.', C.dim)
appendOutput('Status refreshes every 15 seconds.', C.dim)

// ── NSTimer for status refresh every 15s ─────────────────────────
ObjC.registerSubclass({
  name: 'BRRefresher',
  superclass: 'NSObject',
  methods: {
    'refresh:': {
      types: ['void', ['id']],
      implementation: function() {
        const s = getStatus()
        if (s) {
          refreshStatus(s)
          if (s.checks.is && s.checks.is.status === 'red') {
            dotFields['is'].textColor = C.red
            dotFields['is'].stringValue = '●'
          }
        }
      }
    }
  }
})

const refresher = $.BRRefresher.alloc.init
$.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
  REFRESH_S, refresher, 'refresh:', $(), true)

// ── Show panel and run event loop ─────────────────────────────────
panel.makeKeyAndOrderFront(null)
app.activateIgnoringOtherApps(true)

// app.run exits immediately in shell context — use NSRunLoop directly
const runLoop = $.NSRunLoop.mainRunLoop
while (true) {
  runLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.5))
}
