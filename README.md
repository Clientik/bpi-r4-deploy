# BPI-R4 — Fibocom FM350-GL 5G modem support (fork)

This branch (`FM350-GL-Support`) is a **fork of
[woziwrt/bpi-r4-deploy](https://github.com/woziwrt/bpi-r4-deploy)** that adds
**Fibocom FM350-GL 5G modem** support to the Banana Pi BPI-R4 build.

> **All the base documentation lives upstream.** Board variants, flashing,
> NVMe/eMMC install, sysupgrade, the UniFi stack, forking & building,
> architecture and the NVMe layout are unchanged from upstream — see the
> upstream README:
> <https://github.com/woziwrt/bpi-r4-deploy/blob/main/README.md>
>
> Everything below is the **delta specific to this fork**. The universal LED
> and modemdata improvements live in their own branches (`led-fix`,
> `modemdata-fix`); only the modem-specific pieces are added here.

## What this fork adds on top of upstream

- **PCIe2 disable** so the FM350-GL comes up in **USB/RNDIS out of the box**
  — overlay `480-w-add-bpi-r4-nopcie2.patch` + U-Boot env `481-w-add-bpi-r4-nopcie2-env.patch`,
  toggleable from the U-Boot console (see below).
- `atc-fib-fm350_gl` ATC proto package + `luci-proto-atc` (RNDIS via AT commands).
- `kmod-mtk-t7xx` blacklist + the USB hotplug init for the modem.
- **Green LAN-port LED fix** (patches `470`/`471` + `/etc/init.d/mtk-led-fix`).
- **zapret (nftables) kernel dependency baked in** (`kmod-nft-queue`) — see
  *Known issues & tips*.

All upstream U-Boot patches (`450`–`455`) and `filogic.mk` are left **pristine**;
every change above is delivered as its own file / patch so future upstream
updates don't collide.

## Fibocom FM350-GL 5G modem (M.2 Key-B slot)

The FM350-GL is supported in **USB/RNDIS mode** via the `atc-fib-fm350_gl` package.

### How it works

The M.2 Key-B slot (CN16) connects to both PCIe2 and USB lines. The FM350-GL chooses its mode at hardware level based on whether a PCIe link is detected at boot:

- **PCIe2 active** -> modem enters T7xx/PCIe mode -> MBIM protocol
- **PCIe2 disabled** -> modem uses USB lines -> RNDIS protocol -> configured via AT commands

By default this build disables PCIe2 so the modem works out of the box in USB/RNDIS mode without any manual setup.

### LAN port LEDs

On the MTK SDK build the 4 LAN gphys bind to the Generic PHY driver under the
mt7530-mmio DSA switch, so nothing configures the port LEDs and they stay dark.
This build fixes the **green** LED:

- `470-w-add-bpi-r4-leds-overlay.patch` muxes the gphy LED pins (runtime overlay
  in `bootconf_extra`, same mechanism as `nopcie2`).
- `/etc/init.d/mtk-led-fix` programs the gphy LED registers at boot via
  `mdio-tools`: green = on at link + blink on tx/rx. Per-port polarity is
  board-specific: WAN/LAN1/LAN2 are active-low (`0xc007`), LAN3 is
  active-high (`0x8007`) - wrong polarity lights the LED with no link.
- `CONFIG_LED_TRIGGER_PHY=y` is enabled in the kernel.
- To avoid the brief WAN/LAN1 flash at boot (the active-low ports sit in their
  inverted gphy power-on default until userspace runs), U-Boot programs the LED
  ON_CTRL registers before the kernel. This lives in its own standalone patch
  `471-w-bpi-r4-led-uboot.patch` (it does not edit woziwrt's U-Boot patches):
  `CONFIG_CMD_MDIO=y` plus `mdio write mt7988 <phy> 1f.24 ...` prepended inline
  to `bootcmd`. The kernel keeps these values, so the ports stay dark from
  power-on. `mtk-led-fix` still runs in Linux to add the activity blink.

The **amber/right** LED is *not* wired to a controllable output on the BPI-R4
(confirmed: gphy LED1 force-on does nothing, mainline configures led0 only, and
the schematic marks `RJ45_LED_C/D` as NC), so only the green LED can be driven —
this is a board hardware limitation, not a software one.

### Toggle PCIe2 via U-Boot console

PCIe2 is switched by adding/removing the `nopcie2` overlay in `bootconf_extra`.

This build also carries the `leds` overlay in `bootconf_extra`, so keep it when
toggling PCIe2.

**Default (USB/RNDIS) - already flashed:**
```
bootconf_extra=mt7988a-bananapi-bpi-r4-leds#mt7988a-bananapi-bpi-r4-nopcie2
```

Interrupt boot over serial, then:

#### Enable PCIe2 (MBIM mode) — keeps the LEDs
```
setenv bootconf_extra mt7988a-bananapi-bpi-r4-leds
saveenv
```

#### Restore USB/RNDIS (default)
```
setenv bootconf_extra mt7988a-bananapi-bpi-r4-leds#mt7988a-bananapi-bpi-r4-nopcie2
saveenv
```

> NAND: prepend `mt7988a-bananapi-bpi-r4-spim-nand#mt7988a-bananapi-bpi-r4-emmc#` to the value. After saveenv, do a full power cycle.

### Network interface setup (LuCI)

After flashing, create a WAN interface with protocol **ATC** and device `/dev/ttyUSB2` (or whichever ttyUSB responds to `AT`). The `atc-fib-fm350_gl` script configures the modem and brings up the RNDIS interface automatically.

### Known issues & tips

- **Docker can overlap the modem IP range.** Docker's default address pool
  (172.16/12, plus the CGN 10.x ranges used by some carriers) can collide with
  the addresses the modem/RNDIS interface gets, and after boot the WAN may come
  up before Docker has settled. If the modem interface misbehaves right after a
  reboot, the simplest fix is to **recreate (down/up) the ATC interface about
  10 minutes after boot** — by then Docker and the modem have stabilized and it
  comes up cleanly.

- **Use separate ttyUSB ports for data vs. internet.** The FM350 exposes several
  AT-capable `ttyUSB` ports but they share one AT engine, so two consumers
  hitting the modem at once get `CME ERROR` / overlapping replies. Point each at
  its own port — for example **modemdata polling on `ttyUSB1`** and the **ATC
  internet interface on `ttyUSB3`** (adjust to whichever ports answer `AT` on
  your unit). This keeps the status polling from interfering with the data
  connection.

- **Zapret / DPI bypass — use nftables mode.** OpenWrt 25.12 runs firewall4
  (nftables), and a self-built image cannot install `kmod-*` from the public
  feed (kernel vermagic mismatch). So this build bakes in the one kernel module
  zapret needs in **nftables** mode: `kmod-nft-queue` (pulls `kmod-nfnetlink-queue`).
  Everything else for the nftables path (`nftables`, `kmod-nft-nat`) is already
  in the firewall4 image; `curl`/`coreutils-sort`/`coreutils-sleep`/`gzip` are
  baked too so the installer runs offline. When installing
  [zapret4rocket](https://github.com/IndeecFOX/zapret4rocket) (or any bol-van
  zapret), **switch the firewall type to `nftables`** (`FWTYPE=nftables`) — the
  default `iptables` path pulls a large `iptables-mod-*` / `ip6tables-extra`
  stack whose `kmod-*` are not installable on a custom build.
