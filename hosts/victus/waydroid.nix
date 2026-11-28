{...}: {
  # Waydroid — Android in an LXC container. Victus only, his word 2026-11-28:
  # "+add waydroid vict only".
  #
  # The kernel already has binder built in (CONFIG_ANDROID_BINDER_IPC=y,
  # CONFIG_ANDROID_BINDERFS=y, devices "binder,hwbinder,vndbinder"), so the
  # module's requiredKernelConfig assertions pass with no extra kernelModules.
  #
  # It only runs inside a Wayland session — Hyprland or Cinnamon on Wayland.
  # The X11 session cannot host it. Images still need a one-time
  # `sudo waydroid init` (they are downloaded, not packaged).
  virtualisation.waydroid.enable = true;
}
