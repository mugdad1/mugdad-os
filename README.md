# nixos-config

Personal NixOS flake for three machines. **Not for public use.** Originally
forked from [Frost-Phoenix/nixos-config](https://github.com/Frost-Phoenix/nixos-config).

Long-form documentation lives in the wiki: `~/projects/wiki/projects/nixos-config.md`
(history and decisions: `~/projects/wiki/decisions.md`).

## Hosts

All three deploy from `main`.

| Host | Role | Platform |
| --- | --- | --- |
| `victus` | Daily laptop — Cinnamon + Hyprland, home-manager, Intel iGPU + RTX 3050 | HP Victus 15, i5-12500H |
| `t480s` | Second laptop — Cinnamon + Hyprland, home-manager, Intel iGPU only | ThinkPad T480s |
| `asus` | Headless server — Forgejo, gitea-mirror, SearXNG, study, blocky | ASUS X509, i3-8xxxU |
| `grandpa` | Headless server — nginx, HA, blocky, Docker engine, router reboot | Custom i3-2120 |

`grandpa` imports `modules/core` only: no desktop, no home-manager. Its
`variables.nix` declares no `browser`/`terminal`/`launcher`, and
`modules/core/user.nix` imports `modules/home` only when `variables ? browser`.

## Layout

```
flake.nix                 # mkHost: hosts/<host>; specialArgs host/inputs/variables
lib/default.nix           # scanPaths — recursive module auto-import
lib/gruvbox.nix           # palette
lib/server-index.nix      # grandpa's index page
hosts/
  victus/                 # default.nix, battery-charge-limit.nix, hardware-configuration.nix, variables.nix
  t480s/                  # default.nix, hardware-configuration.nix, variables.nix
  asus/                   # default.nix, packages.nix, study.nix, searxng.nix,
                          #   gitea-mirror.nix, hardware-configuration.nix, variables.nix
  grandpa/                # default.nix, packages.nix, overrides.nix, router-reboot.nix,
                          #   home-assistant.nix, services.nix,
                          #   hardware-configuration.nix, variables.nix
modules/
  core/                   # shared system layer — every host (16 files)
  desktop/                # desktop environment — laptops only (9 files)
  home/                   # home-manager stack — only where variables declare a desktop
    terminal/             # cli, dev, fish, foot, glow, lazyvim, shell
    apps/                 # browser, git, gui, homepage, vscodium, xdg
    desktop/              # theme, osd, swaylock + variables.nix, hyprland/, waybar/, rofi/, swaync/
pkgs/                     # callPackage files: filen-cli.nix, filen-desktop.nix, gitea-mirror.nix
scripts/                  # wrapped shell scripts (scripts/default.nix)
  grandpa/ac.sh           # read directly by hosts/grandpa/packages.nix
assets/fonts/ assets/wallpapers/
```

## Import rules

These are opposite on purpose. Getting either wrong fails silently — a green
build says nothing about a file that was never imported.

1. **`hosts/<name>/` — explicit imports only.** A directory module resolves to
   its `default.nix` only; it does not sweep up siblings. Every file under
   `hosts/<name>/` must be named in that host's `imports` list.
2. **`modules/{core,desktop,home}/` — recursive `scanPaths`.** Any `.nix` file
   dropped in these trees is imported; a subdirectory with its own
   `default.nix` owns its children. `modules/home/default.nix` additionally
   imports `scripts/default.nix`, which is outside the tree.
3. **`scripts/` — explicit.** Each script is wrapped by name in
   `scripts/default.nix`. `scripts/grandpa/ac.sh` is read directly by the
   grandpa package list, which has no home-manager.

Verify a new unit with `nix eval` on `config.systemd.services.<name>` rather
than trusting the build result.

## Rebuild

```bash
mcli rebuild                 # nh os switch ~/nixos-config; host from hostname
mcli update                  # flake update + rebuild

sudo nixos-rebuild switch --flake ~/nixos-config#victus
sudo nixos-rebuild switch --flake ~/nixos-config#t480s
sudo nixos-rebuild switch --flake ~/nixos-config#grandpa
sudo nixos-rebuild switch --flake ~/nixos-config#asus
```

## Secrets

None are tracked. The repo is public and declares no credential and no secret
tooling. `filen-sync` authenticates through the `filen` CLI's own login state in
the user's home (`filen login` once per server); SearXNG uses a fixed
cookie-signing key in `hosts/asus/searxng.nix`, which is not a credential.

## Development

```bash
nix develop                  # alejandra, shfmt, stylua, taplo, statix, deadnix, shellcheck, nixd
nix fmt                      # treefmt (alejandra/shfmt/stylua/taplo)
alejandra --check $(git ls-files '*.nix')
statix check
deadnix --fail
nix flake check
```

`nix fmt` currently fails when `stylua` is not on `PATH`; run `alejandra`
directly in that case.

`install.sh` is a whiptail installer for a fresh machine. It detects the host
from DMI, rewrites `username`, copies `/etc/nixos/hardware-configuration.nix`
into the host directory, and runs the first switch. Regenerate
`hardware-configuration.nix` on the target and diff — never hand-write it.

`asus` is the exception: it mounts by label (`ASUSBOOT`, `asus-root`,
`asus-storage`), so the installer keeps its hand-written
`hardware-configuration.nix` instead of replacing it with the UUID-based one.
That is what lets the SSD and HDD be swapped, or the HDD moved into a USB
enclosure, without editing the config.
