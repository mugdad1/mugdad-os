# ASUS X509 (i3-8xxxU, 8 GiB, RTL8821CE) — headless Wi-Fi server: the board,
# RAM, Wi-Fi card and the 512 GB SK hynix SATA SSD, nothing else. No screen,
# no keyboard, and **no battery pack** — the EC still exposes BAT0 with
# `present=1`, but it reports 0 energy and no capacity, so there is nothing to
# charge-limit (the old asus-charge-limit unit was removed 2026-11-20).
# No second disk is fitted as of 2026-11-19; the /srv/storage mount below is a
# reserved slot, not current hardware.
# 8 GiB since the fleet RAM swap on 2026-11-20 (4 + 4 DDR4-2400, both slots);
# it was a single 4 GiB stick before that.
# Imports modules/core plus host-local siblings; never modules/desktop.
{
  lib,
  pkgs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ./packages.nix
    ./study.nix
    # Moved from grandpa 2026-11-18.
    ./searxng.nix
    ./gitea-mirror.nix
  ];

  boot.loader.efi.efiSysMountPoint = "/boot";

  # The root disk is an SSD; the platter is storage only.
  boot.kernelParams = [
    "rootflags=noatime"
    "nowatchdog"
    "psi=1"
  ];

  # RTL8821CE (10ec:c821) is driven by the in-tree rtw88_8821ce; the
  # out-of-tree rtl8821ce package was dropped from nixpkgs. Both quirks below
  # cost this chip its link: PCIe ASPM drops it under load, deep power save
  # stalls it when idle. There is no wired uplink to fall back to.
  boot.kernelModules = ["rtw88_8821ce"];
  boot.extraModprobeConfig = ''
    options rtw88_pci disable_aspm=1
    options rtw88_core disable_lps_deep=1
  '';

  # Reserved slot for a future disk. Label, not UUID, so the disk can move to
  # a USB enclosure without editing anything; nofail so no disk never blocks
  # boot. No platter is fitted as of 2026-11-19.
  fileSystems."/srv/storage" = {
    device = "/dev/disk/by-label/asus-storage";
    fsType = "ext4";
    options = ["nofail" "x-systemd.device-timeout=10"];
  };

  # 8 GiB with no desktop (4 GiB before 2026-11-20): compressed swap still
  # protects the budget if a build spikes.
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
    priority = 100;
  };

  # Forgejo moved here from grandpa on 2026-11-18 along with its SQLite state
  # in /var/lib/forgejo. Pin the uid because that data is chowned to 1002/1002:
  # 994/991 (grandpa's old numbers) are taken by rtkit on this box.
  users.users.forgejo.uid = 1002;
  users.groups.forgejo.gid = 1002;

  services.forgejo = {
    enable = true;
    settings = {
      server = {
        DOMAIN = "100.92.54.61";
        ROOT_URL = "http://100.92.54.61:3000/";
        HTTP_PORT = 3000;
        LANDING_PAGE = "explore";
      };
      service = {
        # Open so the first account becomes admin; close it after first login.
        DISABLE_REGISTRATION = false;
        REQUIRE_SIGNIN_VIEW = false;
      };
      repository.DEFAULT_BRANCH = "main";
    };
    database.type = "sqlite3";
    stateDir = "/var/lib/forgejo";
  };

  # Garbage collection is already fleet-wide: modules/core/nh.nix enables
  # programs.nh.clean (weekly, --keep-since 14d --keep 10). Turning on
  # nix.gc.automatic as well would run a second collector against the same
  # store, so it stays off here too.

  # smartd watches the SSD; there is no second disk to watch right now.
  # No mail transport on this box: findings land in the journal.
  services.smartd = {
    enable = true;
    notifications.wall.enable = false;
  };

  # It is a server: nothing may suspend it. There is no lid to switch on, so
  # the old HandleLidSwitch entries and the battery charge limit are gone
  # (2026-11-20) — this box has no pack, as BAT0 reports 0 energy.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Same resolver as grandpa: this box is also at home, where DoT/DoQ are not
  # blocked, so it races the encrypted transports itself instead of DoH, and
  # answers the LAN as well as loopback. Kept in sync with
  # hosts/grandpa/overrides.nix.
  services.blocky.settings.upstreams.groups.default = lib.mkForce [
    "tcp-tls:cbf8aa.dns.nextdns.io:853"
    "quic:2b44bd66.d.adguard-dns.com"
  ];
  services.blocky.settings.ports.dns = lib.mkForce "0.0.0.0:53";
  # 3000 is Forgejo, moved here from grandpa with the other two web services.
  networking.firewall.allowedTCPPorts = [53 3000];
  networking.firewall.allowedUDPPorts = [53];

  users.users.${username} = {
    extraGroups = ["users"];

    # victus holds the only keypair in the fleet; key auth means no password
    # typing on a box with no keyboard attached.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHTAV1WMtmBZ3PMicT0QFN78AUU5eEZuzam2tu136yeZ"
    ];
  };

  # The only tool list this host adds itself; everything else comes from
  # ./packages.nix, which mirrors grandpa's server set.
  environment.systemPackages = with pkgs; [
    iw
  ];
}
