# The ELAN I2C touchpad on the Victus powers up in "mouse mode" (report 1,
# relative X/Y only). Linux binds the generic hid-multitouch driver, which
# does not send the vendor feature report that switches the controller into
# PTP/absolute mode (report 4, real finger coordinates). hid-elan would do it,
# but this PID (04F3:321A) is not in its ID table. Without the switch,
# libinput gets no ABS_MT events and two-finger scrolling cannot work.
#
# This oneshot sends the ELAN mode-switch feature report, then rebinds the
# driver so the kernel re-enumerates the pad in its new mode. The marker in
# /run keeps udev add events from re-triggering the rebind in a loop.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.victus.elanTouchpadPtp;

  switchScript = pkgs.writeText "elan-ptp-switch.py" ''
    import fcntl
    import glob
    import os
    import time

    HID_GLOB = "/sys/bus/hid/devices/0018:04F3:321A.*"
    MARKER = "/run/elan-ptp-mode.done"
    # Feature report 3: ELAN's vendor command to enable PTP/absolute mode.
    MAGIC = bytes([0x03, 0x33, 0x03, 0x06, 0x00, 0x05, 0x00, 0x03, 0x03, 0x00])

    def log(message):
        print("elan-ptp: " + message, flush=True)

    def hid_device():
        matches = sorted(glob.glob(HID_GLOB))
        return matches[0] if matches else None

    def hidraw_node(hid):
        nodes = glob.glob(hid + "/hidraw/hidraw*")
        return "/dev/" + os.path.basename(nodes[0]) if nodes else None

    def set_feature(node, payload):
        request = (3 << 30) | (len(payload) << 16) | (ord("H") << 8) | 6
        with open(node, "rb+", buffering=0) as handle:
            fcntl.ioctl(handle.fileno(), request, bytearray(payload), True)

    def rebind(hid):
        name = os.path.basename(hid)
        driver = os.path.basename(os.readlink(hid + "/driver"))
        base = "/sys/bus/hid/drivers/" + driver
        with open(base + "/unbind", "w") as handle:
            handle.write(name)
        time.sleep(0.5)
        with open(base + "/bind", "w") as handle:
            handle.write(name)

    if os.path.exists(MARKER):
        log("already switched this boot")
        raise SystemExit(0)

    hid = None
    for _ in range(120):
        hid = hid_device()
        if hid and hidraw_node(hid):
            break
        time.sleep(0.25)
    else:
        log("timed out waiting for the ELAN HID device")
        raise SystemExit(1)

    node = hidraw_node(hid)
    log("switching to PTP mode via " + node)
    set_feature(node, MAGIC)
    time.sleep(0.3)
    rebind(hid)

    with open(MARKER, "w") as handle:
        handle.write("1\n")
    log("done")
  '';
in {
  options.services.victus.elanTouchpadPtp.enable = lib.mkEnableOption ''
    switch the HP Victus ELAN touchpad into PTP mode so two-finger scrolling works
  '';

  config = lib.mkIf cfg.enable {
    boot.kernelModules = ["hid_multitouch"];

    systemd.services.elan-ptp-mode = {
      description = "Enable PTP mode on the ELAN touchpad (two-finger scroll)";
      wantedBy = ["multi-user.target"];
      after = ["systemd-modules-load.service" "systemd-udev-settle.service"];
      wants = ["systemd-modules-load.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.python3}/bin/python3 ${switchScript}";
        TimeoutStartSec = 60;
      };
    };
  };
}
