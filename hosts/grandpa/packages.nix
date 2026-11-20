# grandpa-only additions to the shared server set in ../common/server-packages.nix.
{pkgs, ...}: {
  imports = [../common/server-packages.nix];

  environment.systemPackages = with pkgs; [
    # `ac` — one command for the AC. writeShellApplication pins its runtime
    # deps and runs shellcheck at build time. The Midea dongle lives next to
    # this box.
    (writeShellApplication {
      name = "ac";
      runtimeInputs = [curl python3];
      text = builtins.readFile ../../scripts/grandpa/ac.sh;
    })

    # python3 with the AC/serial libraries used for dongle probing.
    (python3.withPackages (p: [p.pyserial p.aioesphomeapi]))
    picocom

    # Agent tooling: node for the study repo's tests.
    nodejs
  ];
}
