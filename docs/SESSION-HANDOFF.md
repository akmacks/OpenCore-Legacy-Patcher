# OCLP 3.0.0 Dev Ñ Session Handoff
## For: Next Claude instance (new chat Ñ started FROM Mac mini)
## Generated: 2026-03-27 | Session 3 close
## Project: OpenClaw Legacy Patcher

---

## YOU ARE RUNNING ON THE MAC MINI

The user has opened this new Claude session from the Mac mini browser.
This changes everything Ñ you have DIRECT access to the mini as the host machine.

Desktop Commander MCP on the mini gives you full local shell access.
You do NOT need SSH tunnels to reach the mini. You ARE on the mini.

To reach the MBP from here, use:
  ssh pro         connects to MacBook-Pro-i9 at 192.168.2.1

---

## FIRST THING TO DO

Run this to confirm you are on the mini and internet is working:
  hostname && ping -c 1 8.8.8.8 && sw_vers

Expected output:
  Mac-mini-Server-i7.local
  1 packets transmitted, 1 packets received
  macOS 26.3.1

---

## MACHINE REFERENCE

Mac mini (YOU ARE HERE)
  hostname:   Mac-mini-Server-i7
  model:      Macmini5,3 (Late 2011 Server)
  user:       akmacks
  password:   k@r1
  sudo:       NOPASSWD Ñ no password needed
  OS:         macOS Tahoe 26.3.1 (Build 25D2128, Darwin 25.3.0)
  OCLP repo:  ~/OpenCore-Legacy-Patcher/
  CPU:        Intel Core i7-2635QM (Sandy Bridge)
  GPU:        Intel HD 3000 + AMD Radeon HD 6630M
  Ethernet:   Broadcom BCM5722 (BROKEN Ñ kext missing)
  Wi-Fi:      BCM43xx
  Audio:      ALC892
  Internet:   Via Thunderbolt bridge from MBP (NAT)

MacBook Pro (controller / reach via ssh pro)
  hostname:   MacBook-Pro-i9
  user:       akmacks
  OCLP repo:  ~/Documents/Github/OpenCore-Legacy-Patcher/ (git, macos-next branch)
  IP on TB:   192.168.2.1

---

## CURRENT HARDWARE STATUS

Component           Status      Notes
-----------         -------     -----
macOS Tahoe boot    WORKING     Boots via OC EFI on disk0s1
GPU / colour        BROKEN      OCLP root patches NEVER applied
USB HID             WORKING     Synergy removed, usb11.py patched
SSH from MBP        WORKING     Via reverse tunnel on port 2222
ARD (screen share)  WORKING     From MBP
Internet on mini    WORKING     Via TB bridge NAT (fragile Ñ may need reconnect)
Ethernet BCM5722    BROKEN      BCM5722D.kext missing entirely from OCLP payloads
Wi-Fi BCM43xx       UNKNOWN     EFI kexts present, root patches not applied
Audio ALC892        BROKEN      AppleALC in EFI, root patches not applied
Bluetooth           BROKEN      BlueToolFixup in EFI, root patches not applied
Tailscale           NoState     Needs internet + auth Ñ DO THIS FIRST

---

## ROOT CAUSE OF MOST ISSUES

OCLP root patches have NEVER been applied to the booted volume.
  /Library/Application Support/com.dortania.OpenCore-Legacy-Patcher/AppliedPatches.plist
  Does not exist.

Applying root patches will fix: GPU colour, audio, likely Wi-Fi, Bluetooth.
OpenCore-Patcher.app is at /Applications/OpenCore-Patcher.app
Python 3.14 is at /usr/local/bin/python3.14

---

## PRIORITY TASK LIST

1. AUTHENTICATE TAILSCALE (do this first Ñ permanent fix for connectivity)
   tailscale up
   Approve the URL that appears Ñ open it in Safari on the mini
   tailscale ip -4   should give 100.x.x.x

2. APPLY OCLP ROOT PATCHES (fixes GPU colour + audio + Wi-Fi + BT)
   Open /Applications/OpenCore-Patcher.app
   Click Post-Install Root Patches
   Apply and reboot
   OR via CLI Ñ check: /Applications/OpenCore-Patcher.app/Contents/MacOS/OpenCore-Patcher --help

3. FIX ETHERNET (BCM5722D.kext)
   BCM5722D.kext is missing from OCLP payloads entirely.
   Need to source it from Catalina/Monterey installer.
   Add to ~/OpenCore-Legacy-Patcher/payloads/Kexts/Ethernet/
   Create patchset in sys_patch/patchsets/hardware/ethernet/
   Wire into model_array.py for Macmini5,3
   Add to EFI config.plist and rebuild EFI

4. SYNC OCLP REPO CHANGES BACK TO MBP
   rsync -avz ~/OpenCore-Legacy-Patcher/ pro:~/Documents/Github/OpenCore-Legacy-Patcher/ --exclude='.git'

---

## EFI STATUS (disk0s1)

Mount EFI:
  sudo diskutil mount disk0s1

Kexts in EFI (/Volumes/EFI/EFI/OC/Kexts/):
  AMFIPass, ASPP-Override, AirportBrcmFixup, AppleALC
  AppleIntelCPUPowerManagement(Client), AutoPkgInstaller
  BigSurSDXC, BlueToolFixup, CatalinaBCM5701Ethernet (WRONG Ñ not BCM5722)
  CatalinaIntelI210Ethernet, CryptexFixup, ECM-Override
  IO80211FamilyLegacy, IOSkywalkFamily, Lilu
  RSRHelper, RestrictEvents, USB-Map

MISSING: BCM5722D.kext

---

## OCLP REPO

Mini:  ~/OpenCore-Legacy-Patcher/           (rsync copy)
MBP:   ~/Documents/Github/OpenCore-Legacy-Patcher/  (git, macos-next branch)

Key changes made in previous sessions:
  detect.py                             OS ceiling extended to Tahoe
  constants.py                          is_patching_external_volume flag
  wx_gui/gui_main_menu.py              external disk detection
  sys_patch/patchsets/hardware/audio/modern_audio.py   15.2 PSP fallback
  support/subprocess_wrapper.py         sudo direct (dev only)
  sys_patch/patchsets/hardware/usb/usb11.py   Macmini5,1/2/3 added

---

## RECONNECT TUNNEL (if internet drops)

On mini terminal:  tunnel-pro
On MBP terminal:   ~/scripts/reconnect-mini.sh

If port 2222 conflict: on MBP run: sudo kill $(lsof -ti :2222)

---

## SESSION HISTORY
Session 1: https://claude.ai/chat/aee6f07c-e9b4-47ad-aca4-ffd76a19df4f
Session 2: https://claude.ai/chat/3c791c6b-be12-4f24-850f-270b44db9fb7
Session 3: This session Ñ tunnel established, docs written, repo synced, reverse tunnel implemented

---
Generated: 2026-03-27 | Verify everything with diagnostics before assuming state
