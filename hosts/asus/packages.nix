# asus-only additions to the shared server set in ../common/server-packages.nix.
#
# No AC dongle stack here: `ac`, pyserial/aioesphomeapi and picocom stay on
# grandpa, next to the hardware. filen-cli was removed with Filen on
# 2026-11-20 (row 274).
{pkgs, ...}: {
  imports = [../common/server-packages.nix];

  environment.systemPackages = with pkgs; [
    # hosts/asus/study.nix runs scripts/serve.py (stdlib only, but it is python).
    python3
  ];
}
