# Sardis Technologies ST-2900 Build Recipes

Build recipes for the ST-2900 (6809/6309 SS-50 system with an MC2681 DUART
console, floppy and DriveWire storage).

## Prerequisites

```sh
export NITROS9DIR=$HOME/nitros9
```
Tools on `PATH`: `make`, `lwasm`, `lwlink`, `lwar`, `os9`.

## Build Directories

| Recipe | CPU | Boot | Output image |
| --- | --- | --- | --- |
| [`floppy/`](floppy/)         | 6809 | floppy (80-track DD) | `NOS9_6809_L1_DEV_st2900.dsk` |
| [`dw/`](dw/)                 | 6809 | DriveWire            | `NOS9_6809_L1_DEV_st2900_dw.dsk` |
| [`dd_dw/`](dd_dw/)           | 6809 | floppy + DriveWire   | `NOS9_6809_L1_DEV_st2900_dd_dw.dsk` |
| [`floppy_6309/`](floppy_6309/) | 6309 | floppy             | `NOS9_6309_L1_DEV_st2900.dsk` |
| [`dw_6309/`](dw_6309/)       | 6309 | DriveWire            | `NOS9_6309_L1_DEV_st2900_dw.dsk` |

```sh
cd floppy
make
```

Intermediates stay local per build dir (`.obj/`, `.lib/`, `.mods/`).
The 6309 recipes set `CPU = 6309` and `AFLAGS_EXTRA += -DH6309=1`; `PORT`
stays `st2900` so all sources and the port `defsfile` resolve to the shared
`level1/st2900` and `level1/modules` trees.

## How the ST-2900 boots

Like the Pico-Thing, the ST-2900 carries two files rather than a boot track:

- **`OS9Kernel`** — `krn krnp2 init_st2900` followed by a boot block,
  merged and padded to exactly 3840 bytes so it occupies `$F000-$FEFF`.
  The boot block is `boot_st2900`, zero padding, then a raw FEXX data block
  (`boot_st2900_data`) that must end at `$FF00` — the ST-2900 boot ROM
  jumps to a fixed address inside it. The padding size is computed from the
  boot-module and FEXX-block lengths at build time.
- **`OS9Boot`** — the merged bootfile: `ioman`, the RBF + `sdisk29` floppy
  stack, SCF + the MC2681 console, pipes, the clock and `sysgo1`. The
  DriveWire recipes boot from `ddx0` instead and add the DriveWire RBF/SCF
  stack (`rbdw`, `dwio_mc2681`, `scdwv`, `scdwp`, virtual channels).

The DriveWire transport uses the MC2681's second serial port at 38400 baud
(`dwio_mc2681.sb`, built from the shared `dwio`/`dwinit`/`dwread`/`dwwrite`
with `-DMC2681=1`).

## Not yet converted

These parts of the old top-level build have not been carried into recipes;
none are needed to boot the base images:

- The 5.25" 40-track two-disk distribution set (`_40d_1` / `_40d_2`) and the
  720K `_80d` distribution layout that also populate a `/NITROS9`
  directory tree (MODULES, BOOTLISTS, SCRIPTS). The bootlists and mb
  scripts remain under `level1/st2900/` for that future work.
- The on-disk `/DD/DEFS` reference directory the old build generated.
