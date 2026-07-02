# Fork delta vs woziwrt/bpi-r4-deploy — merge guide

This fork (`Clientik/bpi-r4-deploy`) = upstream `woziwrt/bpi-r4-deploy` main
**plus the FM350-GL modem stack and a few fork policies**. This file is the
single source of truth for future upstream merges: what is already upstream,
what is fork-only, and which side must win on conflict.

Keep the fork as **one delta commit on top of upstream main** where possible:
`git fetch upstream && git rebase upstream/main` and re-validate (see checklist).

## 1. Already merged upstream — take THEIR side on conflict

| Component | Files | Notes |
|---|---|---|
| LAN LED fix (green, link+activity) | `my_files/470-w-add-bpi-r4-leds-overlay.patch`, `my_files/471-w-bpi-r4-led-uboot.patch`, `my_files/etc-files/init.d/mtk-led-fix`, `my_files/etc-files/uci-defaults/95-mtk-led-fix-enable`, LED lines in the two universal builders | Originated in this fork (`led-fix`), merged upstream and then **improved there**: phy2 (LAN2) polarity is boot-medium dependent (eMMC `0xc007`, SD/NAND `0x8007`, runtime-detected). Upstream version is canonical — do NOT resurrect the fork's older all-static polarity. |
| modemdata race fix (sms_tool addons) | `my_files/modemdata-main/**` (addons/params) | Originated in this fork (`modemdata-fix`). BUT see section 2 — upstream regressed `product.sh`. |

## 2. Fork-only fixes upstream got WRONG or lost — keep OUR side on conflict

| Component | Files | Why ours wins |
|---|---|---|
| **modemdata identification via sysfs** | `my_files/modemdata-main/files/usr/share/modemdata/product.sh`, `.../libs/getdevicevendorproduct`, `.../vendorproduct/**` (incl. `usb/0e8d7126`, `usb/0e8d7127` — real files, upstream carried a broken `.lnk`) | Upstream's `product.sh` regressed to **gcom** (async AT on a port the addons/ATC also use) → response overlap → `+CME ERROR 3`, missing temp/bands. Ours identifies the modem from **sysfs VID:PID with no AT traffic at all** (race-free, HW-validated). Fixed in commit `23dff44`. Candidate to PR upstream. |
| **mdio-tools in defconfigs** | `CONFIG_PACKAGE_mdio-tools=y`, `CONFIG_PACKAGE_kmod-mdio-netlink=y` in `configs/my_defconfig-*` | Upstream's own `mtk-led-fix` needs the `mdio` binary at runtime but their defconfigs lost the package (LED blink silently no-ops without it). Candidate to PR upstream. |

## 3. Fork-only features — keep OUR side, upstream does not have these

| Component | Files | Notes |
|---|---|---|
| **PCIe2 disable (FM350 USB/RNDIS mode)** | `my_files/480-w-add-bpi-r4-nopcie2.patch` (DT overlay), `my_files/481-w-add-bpi-r4-nopcie2-env.patch` (U-Boot env: `bootconf_extra += #nopcie2`), copy lines + `sed` (append `nopcie2` to `DEVICE_DTS_OVERLAY` after upstream's `leds` sed) in the two universal builders | **481 applies ON TOP of upstream's 471** and carries 471's post-patch lines as context (incl. per-medium phy2 values). ⚠️ If upstream changes `471-w-bpi-r4-led-uboot.patch` or the defenvs, re-generate 481's contexts and re-run the dry-run check. |
| **FM350 modem stack** | `my_files/atc-fib-fm350_gl/**`, `my_files/luci-proto-atc/**` (vendored into feeds by builders), `my_files/etc-files/modules.d/mtk-t7xx-blacklist`, `my_files/etc-files/hotplug.d/usb/25-fm350-init` | Modem works only via USB/RNDIS; the PCIe T7xx driver is blacklisted. |
| **ModemManager disabled by default** | `my_files/etc-files/uci-defaults/99-disable-modemmanager` + copy lines in builders; `modemmanager` stays in defconfigs | MM races the ATC proto for the modem's single AT engine (boot-order dependent: interface gets an IP but RX=0). Package kept installed; users re-enable with `/etc/init.d/modemmanager enable`. |
| **nikki (mihomo) VLESS client** | `my_files/nikki/**`, `my_files/mihomo-meta/**`, `my_files/luci-app-nikki/**` (vendored into feeds; pinned to nikki upstream `6060401`), defconfig block (kmod-nft-tproxy/-socket, kmod-inet-diag, kmod-dummy, kmod-tun, yq, ca-bundle) | mihomo compiles from Go source at build time. Inactive until a subscription is added (LuCI → Services → Nikki). |
| **zashboard dashboard** | `my_files/nikki/files/nikki.conf` → `option 'ui_url'` | nikki already defaults its `external-ui-url` to zashboard. Fork change: **pinned to `v3.12.1` and `dist.zip`** (self-contained fonts) instead of upstream's `latest`/`dist-cdn-fonts.zip` (CDN fonts fail on a spotty modem link). It downloads on demand via LuCI → Services → Nikki → **Update Dashboard**, then **Open Dashboard** (served at `http://<lan-ip>:9090/ui/`). Bump the version in this one line to update. |
| **zapret (nftables) deps baked** | defconfig: `kmod-nft-queue` (+`kmod-nft-compat`, coreutils-sort/sleep, gzip) | kmods can't be installed from public feeds on a self-built image (vermagic). Install zapret with `FWTYPE=nftables`. |
| build-local.ps1 | repo root | Local WSL2 build wrapper; branch defaults to `main`; no pins (builders self-pin). |
| README FM350 section | `README.md` → "Fibocom FM350-GL 5G modem (this fork)" | Re-add after upstream README changes if lost. |
| .gitattributes LF rules | bottom block (`*.sh`, `*.gcom`, `*.patch`, atc/modemdata/etc-files → `eol=lf`) | BOM/CRLF breaks busybox ash. |

## 4. Fork policies (deliberate deviations)

| Policy | Implementation |
|---|---|
| **No Docker** | All `CONFIG_PACKAGE_docker*/containerd/runc` + `CONFIG_DOCKER_*` removed from `configs/my_defconfig-*`. Upstream keeps docker (split per-medium) — on merge, re-remove. |
| **No strongSwan/IPsec** | All `strongswan*`, `kmod-ipsec*`, `kmod-ipt-ipsec`, `iptables-mod-ipsec`, `CONFIG_STRONGSWAN_*` removed. Remote access is WireGuard / self-hosted mesh instead. |

## 5. Build version pinning (build info variables)

Base source commits live in **`build-versions.env`** (introduced upstream — the
single source of truth for the OpenWrt + MTK SDK pins, read by CI's "Load build
versions" step and defaulted by the builder scripts):

```
OPENWRT_COMMIT=6dead2869209f4ff9825f3169c129c5ef04f6273   # openwrt-25.12 HEAD, 2026-06-28
MTK_COMMIT=13f39a7448764466f0ab5eb290fdefd9a9d2335b       # github git01 HEAD,  2026-06-28
```

- **We track upstream's pins as-is** (do not fork these unless a base bump breaks
  the FM350 delta). To pin the fork to a different base, edit `build-versions.env`
  and the matching `${OPENWRT_COMMIT:-...}` / `git checkout` defaults in the
  builder scripts (both must agree — CI reads the env, a bare builder run reads
  its own default).
- The builders clone the pinned OpenWrt + MTK feeds themselves (github git01,
  not a tarball cache).
- **Fork change — `build-local.ps1`:** removed its own hardcoded
  `OPENWRT_COMMIT`/`MTK_COMMIT` and the `repo-cache` tar logic; it now just
  clones the repo (branch defaults to **`main`**) and runs the builder, which
  self-pins. Keeps the local WSL2 build in sync with CI automatically.
- **Other pinned versions in the fork** (bump deliberately, they are not in
  `build-versions.env`): nikki `6060401` (`my_files/*/Makefile` source refs),
  zashboard `v3.12.1` (`my_files/nikki/files/nikki.conf`).

## 6. Post-merge validation checklist

```sh
# 1. 471 -> 481 apply cleanly (reconstruct defenvs, then):
patch -p1 --dry-run < my_files/471-w-bpi-r4-led-uboot.patch
patch -p1 --dry-run < my_files/481-w-add-bpi-r4-nopcie2-env.patch   # on top of 471
# expected: eMMC keeps phy2=c007, SD/NAND phy2=8007, extra ends ...leds#nopcie2

# 2. product.sh must be the sysfs version (NO gcom):
grep -q getdevicevendorproduct my_files/modemdata-main/files/usr/share/modemdata/product.sh && echo OK

# 3. fork packages present in all defconfigs (expect 8 each):
for p in atc-fib-fm350_gl luci-proto-atc nikki mihomo-meta kmod-nft-queue mdio-tools; do
  printf "%s: " $p; grep -l "CONFIG_PACKAGE_$p=y" configs/my_defconfig-* | wc -l; done

# 4. fork removals still hold (expect 0):
grep -lE "CONFIG_DOCKER_|dockerd=y|strongswan" configs/my_defconfig-* | wc -l

# 5. builders (the two CI uses) still carry the fork blocks:
for f in builder-wifimgr-universal.sh builder-wired-universal.sh; do
  grep -c "480-w-add-bpi-r4-nopcie2\|481-add-bpi-r4-nopcie2\|nopcie2/' target\|99-disable-modemmanager\|atc-fib-fm350_gl\|my_files/nikki " $f; done

# 6. full build (mihomo compiles from Go source — only a real build validates it)
```
