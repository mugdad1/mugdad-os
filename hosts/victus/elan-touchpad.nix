# The ELAN I2C touchpad on the Victus powers up in "mouse mode" (report 1,
# relative X/Y only). Linux binds the generic hid-multitouch driver, which
# does not send the vendor feature report that switches the controller into
# PTP/absolute mode (report 4, real finger coordinates). hid-elan would do it,
# but this PID (04F3:321A) is not in its ID table. Without the switch,
# libinput gets no ABS_MT events and two-finger scrolling cannot work.
#
# The controller is not always ready when its HID node first appears: an early
# feature-report write can succeed at the ioctl level but be ignored. This
# service therefore retries the switch and only reports success after the
# touchpad's evdev node actually advertises multitouch absolute axes.
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

    # evdev absolute-axis bits: SLOT, POSITION_X, POSITION_Y, TRACKING_ID.
    REQUIRED_ABS = (1 << 47) | (1 << 53) | (1 << 54) | (1 << 57)

    def log(message):
        print("elan-ptp: " + message, flush=True)

    def hid_device():
        matches = sorted(glob.glob(HID_GLOB))
        return matches[0] if matches else None

    def hidraw_node(hid):
        nodes = glob.glob(hid + "/hidraw/hidraw*")
        return "/dev/" + os.path.basename(nodes[0]) if nodes else None

    def ptp_active(hid):
        pattern = hid + "/input/input*/event*/device/capabilities/abs"
        for path in glob.glob(pattern):
            try:
                words = open(path).read().split()
                if words and int(words[0], 16) & REQUIRED_ABS == REQUIRED_ABS:
                    return True
            except OSError:
                pass
        return False

    def wait_for_hid(timeout):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            hid = hid_device()
            if hid and hidraw_node(hid):
                return hid
            time.sleep(0.25)
        return None

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

    def mark_success():
        with open(MARKER, "w") as handle:
            handle.write("1\n")

    def main():
        # Fast path, also used on resume: trust only the advertised axes.
        hid = hid_device()
        if hid and ptp_active(hid):
            log("already in PTP mode")
            mark_success()
            return 0

        deadline = time.monotonic() + 180
        attempt = 0
        while time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            hid = wait_for_hid(min(10, remaining))
            if not hid:
                log("ELAN HID device is not ready yet")
                continue

            if ptp_active(hid):
                log("already in PTP mode")
                mark_success()
                return 0

            attempt += 1
            node = hidraw_node(hid)
            log("switch attempt " + str(attempt) + " via " + node)
            try:
                set_feature(node, MAGIC)
                time.sleep(0.3)
                rebind(hid)
            except OSError as error:
                log("switch attempt failed: " + str(error))
                time.sleep(1)
                continue

            # The controller can ignore an early write. Wait for the driver to
            # re-enumerate and verify PTP mode before declaring success.
            for _ in range(40):
                new_hid = hid_device()
                if new_hid and ptp_active(new_hid):
                    mark_success()
                    log("PTP mode confirmed after " + str(attempt) + " attempt(s)")
                    return 0
                time.sleep(0.25)
            log("report sent but PTP mode is not visible yet; retrying")

        log("timed out waiting for ELAN PTP mode")
        return 1

    raise SystemExit(main())
  '';

  execStart = "${pkgs.python3}/bin/python3 ${switchScript}";

  sleepTargets = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
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
        ExecStart = execStart;
        TimeoutStartSec = 240;
      };
    };

    # The pad can fall back to mouse mode across suspend; this is idempotent.
    systemd.services.elan-ptp-mode-resume = {
      description = "Restore ELAN touchpad PTP mode after suspend";
      wantedBy = sleepTargets;
      after = sleepTargets;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = execStart;
        TimeoutStartSec = 240;
      };
    };
  };
}
