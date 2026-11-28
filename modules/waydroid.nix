# Waydroid — Android in an LXC container. Victus first ("+add waydroid vict
# only", 2026-11-28), then t480s ("i liked waydroid add it to t480s also").
#
# The stock kernel has binder built in (CONFIG_ANDROID_BINDER_IPC=y,
# CONFIG_ANDROID_BINDERFS=y, devices "binder,hwbinder,vndbinder"), so the
# module's requiredKernelConfig assertions pass with no extra kernelModules.
#
# It only runs inside a Wayland session (Hyprland, or Cinnamon on Wayland) —
# the Cinnamon X11 session cannot host it. Android images are not packaged:
# they live in /etc/waydroid-extra/images and need `sudo waydroid init -f -i
# /etc/waydroid-extra/images` once per host.
#
# Deliberately no kernel config changes: DMA-BUF heaps would help the
# WayDroid-ATV video path, but any kernel change forces a full Linux compile
# on every host. He chose the stock kernel ("Drop it — no kernel build").
{pkgs, ...}: {
  virtualisation.waydroid = {
    enable = true;

    # The nixpkgs module only auto-selects waydroid-nftables when
    # networking.nftables.enable = true. We keep that off (NixOS still runs an
    # nft firewall), but Waydroid's default package bundles legacy iptables
    # and dies with `modprobe: FATAL: Module ip_tables not found` because the
    # kernel no longer builds the legacy tables. Pick the nftables build
    # explicitly instead of flipping the host firewall backend (waydroid#2094).
    package = pkgs.waydroid-nftables;
  };
}
