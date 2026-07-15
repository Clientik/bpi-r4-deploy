# Fork decision log (indexed)

Chronological "why" behind every fork change, written so a future maintainer
(human or AI) can reconstruct intent quickly. For the authoritative
file-by-file delta and merge rules see **[../FORK-DELTA.md](../FORK-DELTA.md)**;
this file is the narrative index.

## Index

- [D1. Green LAN-port LEDs](#d1-green-lan-port-leds)
- [D2. LED delivered upstream-safe (own patches, not woziwrt's)](#d2-led-upstream-safe)
- [D3. Per-port LED polarity](#d3-per-port-led-polarity)
- [D4. modemdata race fix (sysfs + sms_tool)](#d4-modemdata-race-fix)
- [D5. FM350 USB/RNDIS (PCIe2 disable)](#d5-fm350-usbrndis)
- [D6. ModemManager disabled by default](#d6-modemmanager-disabled)
- [D7. zapret nftables deps baked](#d7-zapret-deps)
- [D8. nikki (mihomo) VLESS client + zashboard](#d8-nikki-zashboard)
- [D9. Docker & strongSwan removed](#d9-docker-strongswan-removed)
- [D10. Rebased onto new upstream base](#d10-rebase-upstream)
- [D11. FM350 packages only in the two supported builders](#d11-supported-builders)
- [D12. FM350 first-boot defaults + mwan3 failover](#d12-defaults-mwan3)
- [D13. fwupdate — OTA updater from this fork's GitHub](#d13-fwupdate)

---

### D1. Green LAN-port LEDs
**Why:** on the MTK SDK build the 4 LAN gphys bind to the Generic PHY driver
under the mt7530-mmio switch, so nothing programs the port LEDs — they stay dark.
**What:** DT overlay muxes the gphy LED pins; `mtk-led-fix` writes the LED
registers over `mdio-tools`; U-Boot programs them pre-kernel to kill the boot
flash. Amber LED is NC on the board — green only. **Merged upstream.**

### D2. LED upstream-safe
**Why:** editing woziwrt's own patch files (450/454) caused merge/hunk conflicts.
**What:** all LED U-Boot bits moved into standalone patches (470/471), overlay
appended in the builder via `sed` instead of editing `filogic.mk`, patch numbers
kept out of woziwrt's 450-455 range. Principle: **never edit upstream's files;
ship our own.**

### D3. Per-port LED polarity
**Why:** LAN2/LAN3 lit with no cable — wrong polarity. Iterated live on hardware.
**Final (HW-verified, upstream's refinement is canonical):** phy0/1 uniform;
**phy2 (LAN2) polarity is boot-medium dependent** (eMMC `0xc007`, SD/NAND `0x8007`),
phy3 `0x8007`. `mtk-led-fix` detects the medium at runtime. An earlier all-`0xc007`
fork attempt was wrong for SD/NAND and was dropped in favour of upstream's version.

### D4. modemdata race fix
**Why:** `+CME ERROR 3`, missing temperature/bands. Root cause: gcom fires AT
asynchronously; on the FM350's single AT engine replies overlap.
**What:** identify the modem via **sysfs VID:PID** (`getdevicevendorproduct`,
no AT traffic at all) and query data via **`sms_tool`** (clean request/response).
**Merged upstream — but upstream later regressed `product.sh` back to gcom;** we
keep the sysfs version (see FORK-DELTA §2). Candidate to re-PR upstream.

### D5. FM350 USB/RNDIS
**Why:** the FM350 picks PCIe(MBIM) vs USB(RNDIS) by whether PCIe2 links at boot.
USB/RNDIS is the reliable path. **What:** `nopcie2` DT overlay (480) + U-Boot env
(481) disable PCIe2; `kmod-mtk-t7xx` blacklisted; USB hotplug init. 481 applies on
top of upstream's 471 and mirrors its per-medium bootcmd context.

### D6. ModemManager disabled
**Why:** MM and the ATC proto both grab the modem's single AT engine; whoever wins
the boot race breaks the other (interface gets an IP but RX=0). Explained the
SD-worked/eMMC-didn't intermittency. **What:** `uci-defaults` disables MM on first
boot; package kept installed (re-enable manually if preferred).

### D7. zapret deps
**Why:** user runs zapret (DPI bypass). On a self-built image kmods can't come from
public feeds (vermagic). **What:** bake `kmod-nft-queue` (nftables path — one kmod,
vs the whole iptables-mod stack). Use zapret in `FWTYPE=nftables`.

### D8. nikki + zashboard
**Why:** VLESS-subscription client. **What:** vendor nikki + mihomo-meta (Go build)
+ luci-app-nikki; bake kernel-tied deps. zashboard is nikki's default dashboard —
pinned to `v3.12.1` `dist.zip` (bundled fonts, reliable on a modem link) instead of
`latest`. Note for RU selective-routing, **podkop** (sing-box) is a lighter,
purpose-built alternative — documented, not adopted.

### D9. Docker & strongSwan removed
**Why:** unused for this router; heavy. Remote access will be WireGuard / a
self-hosted mesh (NetBird planned on an OMV host, P2P — not a hairpin). **What:**
removed from all defconfigs. Re-remove after each upstream merge (upstream keeps
docker split per-medium).

### D10. Rebase upstream
**Why:** led-fix + modemdata-fix were merged upstream and upstream advanced
(per-medium LED, new OpenWrt/MTK pins `6dead28`/`13f39a7`, storage/wifimgr).
**What:** rebuilt the fork as a clean delta on the new `upstream/main` instead of
merging 64 old commits. `main` = FM350 build; backups kept at `backup/*`.

### D11. Supported builders
**Why:** audit found FM350 packages selected in all 8 defconfigs but vendored only
by 2 builders → other variants would fail on missing packages. **What:** FM350
delta lives only in `wifimgr-universal` + `wired-universal` (the pair CI and
build-local use). Consistency rule + checklist 5b in FORK-DELTA.

### D12. Defaults + mwan3
**Why:** make the modem work out of the box and provide automatic backup internet.
**What:** first-boot `99-fm350-defaults` seeds `FB350` (ATC, ttyUSB3, no APN) in the
wan zone + modemdata binding on ttyUSB1 (status port separate from data port);
`mwan3` + luci pre-configured (`/etc/config/mwan3`) for wired→FB350 failover.

### D13. fwupdate
**Why:** the LuCI "Attended Sysupgrade" page targets the OFFICIAL OpenWrt server —
on this MTK-SDK fork it would build/flash a vanilla image without our custom
packages. We want update checks against **this fork's own GitHub releases**
(like BananaWRT does). User asked for it as a proper package, not loose scripts.
**What:** two self-contained, easy-to-remove packages (vendored like nikki/atc):
`fwupdate` (`/usr/sbin/fw-update` CLI: check/list/install + `/etc/config/fwupdate`)
and `luci-app-fwupdate` (System → Firmware Update page). The builder stamps
`/etc/fork-release` (repo/profile/commit/date); `fw-update` resolves the right
release tag + `.itb` by RAM + build profile + PoE (override via uci or the LuCI
variant list parsed from GitHub), compares the release date to the stamp, and
sysupgrades (keeps settings). Removal is a one-block delete (see FORK-DELTA).
Needs a build to package and a run to validate (like nikki/mihomo).
