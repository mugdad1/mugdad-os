_: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.enableRedistributableFirmware = true;

  services.udev.extraRules = ''
    # Disable USB autosuspend to prevent ADB disconnections.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"

    # Hide V4L2 metadata-only nodes (no capture capability) from user-session
    # apps. Some webcams expose an extra /dev/video* node that browsers/Meet can
    # pick, resulting in camera permission granted but no video preview.
    SUBSYSTEM=="video4linux", ENV{ID_V4L_CAPABILITIES}!="*:capture:*", TAG-="uaccess", TAG-="seat", MODE="0600", GROUP="root"
  '';
}
