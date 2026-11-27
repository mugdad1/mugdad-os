# asus-only additions to the shared server set in ../common/server-packages.nix.
#
# No AC dongle stack here: pyserial/aioesphomeapi and picocom stay on grandpa,
# next to the hardware. `ac` itself is in the shared server set — it talks HTTP
# to the ESP8266 over the LAN, so asus can use it too. filen-cli was removed
# with Filen on 2026-11-20 (row 274).
{pkgs, ...}: {
  imports = [../common/server-packages.nix];

  environment.systemPackages = with pkgs; [
    # hosts/asus/study.nix runs scripts/serve.py (stdlib only, but it is python).
    python3
  ];
}
