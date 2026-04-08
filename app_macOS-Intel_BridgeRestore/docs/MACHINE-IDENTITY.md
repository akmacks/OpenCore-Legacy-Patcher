# Machine Identity Reference
## bridge-restore-project

---

## Hardware UUIDs (source of truth for all script guards)

### MacBook Pro i9 (2019)
- **Model Identifier:** MacBookPro16,1
- **Hardware UUID:** 4B4DFAAB-B77A-5B8F-BE93-85E6F990529F
- **Serial:** C02CW18VMD6W
- **bridge0 IP:** 192.168.2.1 — MBP OWNS THIS, ALWAYS
- **Uplink interfaces:** en0 (Wi-Fi), en43 (Belkin USB-C LAN)
- **NAT interfaces:** en0 + en43 (both needed — en43 is primary default route)
- **Internet Sharing:** shares en0/en43 → bridge0 → Thunderbolt
- **Active TB port:** en4 (confirmed multiple sessions)

### Mac mini Server (Late 2011)
- **Model Identifier:** Macmini5,3
- **Hardware UUID:** (not stored — model check sufficient)
- **bridge0 IP:** 192.168.2.2 — MINI OWNS THIS, ALWAYS
- **bridge0 MAC:** 82:0c:4d:eb:46:81
- **Active TB port:** en2 (confirmed)
- **Link-local fallback:** 169.254.94.19

---

## Script Machine Guards

Every script checks hardware identity as its FIRST operation:

```bash
_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')
_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')
```

| Script | Requires | Refuses |
|---|---|---|
| tunnel-mini.sh | MacBookPro16,1 + UUID match | Any other machine |
| tunnel-pro.sh | Macmini5,3 | MBP UUID match |
| bridge-restore.sh | Macmini5,3 | MBP UUID match |
| mini-watchdog.sh | MacBookPro16,1 + UUID | Any other machine |
| pro-watchdog.sh | Macmini5,3 | MBP UUID match |

---

## IP Ownership — Immutable Rule

```
MBP  bridge0 = 192.168.2.1   ← set ONLY by tunnel-mini.sh
Mini bridge0 = 192.168.2.2   ← set ONLY by tunnel-pro.sh and bridge-restore.sh
```

Scripts NEVER set the IP belonging to the other machine.
Violating this rule corrupts routing and breaks the tunnel.
