# Tailscale feature - VPN mesh networking
# Always uses unstable Tailscale for latest features and fixes
{
  config,
  lib,
  pkgs,
  nixpkgs-unstable,
  ...
}:

{
  # Always use unstable Tailscale for the latest features and fixes
  nixpkgs.overlays = [
    (final: prev: {
      tailscale = nixpkgs-unstable.legacyPackages.${prev.system}.tailscale;
    })
  ];

  # Enable Tailscale VPN
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both"; # enables ipv4 and ipv6 net forwarding

  # Trust the Tailscale interface (no firewall restrictions for Tailscale traffic)
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
