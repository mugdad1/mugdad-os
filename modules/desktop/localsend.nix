# LocalSend's firewall half. The app itself is installed by
# modules/home/apps/gui.nix; ports are opened by the module that needs them,
# and a home-manager package cannot open them, so they live here.
#
# TCP 53317: the HTTP server a peer connects to when sending us a file.
# UDP 53317: discovery, multicast group 224.0.0.167. Without both, this host
# is invisible to other devices and cannot receive anything, even though
# outbound transfers still work (the firewall only filters input).
{
  networking.firewall = {
    allowedTCPPorts = [53317];
    allowedUDPPorts = [53317];
  };
}
