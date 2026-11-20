# The tool set both servers share. grandpa and asus import this and add only
# what is tied to their own hardware; modules/home supplies the desktop lists
# and is imported by neither box.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Baseline
    curl
    dnsutils
    jq
    lm_sensors
    ripgrep
    rsync
    tmux
    vim

    # Health sweep (shared script; sections that do not apply say so)
    (writeShellScriptBin "checkup" (builtins.readFile ../../scripts/checkup.sh))

    # Asked for by name
    gh
    git

    # Agent tooling: tcpdump for network debug.
    tcpdump
    (writeShellScriptBin "mcli" (builtins.readFile ../../scripts/mcli.sh))

    # CLI, headless-useful subset
    binutils
    duf
    dust
    entr
    eza
    fd
    file
    glow
    killall
    just
    ncdu
    neovim
    p7zip
    ripgrep-all
    socat
    strace
    tealdeer
    tree
    unzip
    wget
    zip

    # USB probing
    usbutils

    # Box admin: hardware and disks
    btop
    gptfdisk
    hdparm
    htop
    inxi
    iotop
    lazygit
    lsof
    mtr
    parted
    smartmontools
    traceroute

    sqlite
  ];
}
