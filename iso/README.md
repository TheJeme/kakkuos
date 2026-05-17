# KakkuOS ISO Build

This directory contains the first KakkuOS ISO scaffold.

KakkuOS should not maintain a separate ArchISO stack. The ISO build should use
CachyOS' supported live ISO tooling and apply KakkuOS as a profile/overlay on
top of it.

Upstream tooling:

- https://github.com/CachyOS/CachyOS-Live-ISO

## Requirements

Build on a CachyOS or Arch-based system with the CachyOS repositories available.

Install the build tools:

```bash
sudo pacman -S archiso mkinitcpio-archiso git squashfs-tools grub rsync --needed
```

ISO builds use loop mounts, SquashFS, pacstrap, and mkarchiso. They are not a
good fit for restricted containers.

## Prepare The CachyOS Tree

```bash
iso/build-kakku-iso.sh --prepare-only
```

This builds a local KakkuOS package repo, clones or updates CachyOS-Live-ISO
under `iso/.cache/cachyos-live-iso`, copies the current KakkuOS repository into
the live image at `/opt/kakkuos`, injects the local package repo into the live
filesystem, installs Kakku branding assets, removes the CachyOS GUI installer
packages from the live package list, and adds `kakku-desktop` plus
`cachyos-cli-installer-new`.

The live environment gets a `kakku-install` command that launches CachyOS'
terminal installer (`cachyos-installer`) through `sudo`.

## Build

```bash
iso/build-kakku-iso.sh
```

The script currently delegates to:

```bash
sudo ./buildiso.sh -p desktop -v -w
```

inside the cached CachyOS-Live-ISO checkout.

The ISO output is produced by the CachyOS build system under that checkout's
`out/` directory.

## Current Limitations

This is intentionally a scaffold, not the finished release pipeline.

Still needed:

- move from the temporary file-based local package repo to a hosted KakkuOS repo
- wire the CLI installer profile so installed systems select KakkuOS defaults directly
- rename ISO output and live branding from CachyOS desktop to KakkuOS
- VM-test boot, install, first boot, greetd, niri, DMS, and Zen policies

Until those are done, the ISO build is useful for integration work and live
environment experiments, not final end-user releases.
