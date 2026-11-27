# grandpa-only additions to the shared server set in ../common/server-packages.nix.
{pkgs, ...}: {
  imports = [../common/server-packages.nix];

  environment.systemPackages = with pkgs; [
    # `ac` lives in ../common/server-packages.nix now — both servers can reach
    # the ESP8266 over the LAN, so it is no longer grandpa-only.

    # python3 with the serial libraries used for dongle probing.
    (python3.withPackages (p: [p.pyserial p.aioesphomeapi]))
    picocom

    # Agent tooling: node for the study repo's tests.
    nodejs
  ];
}
