# Tailscale feature - VPN mesh networking
# Uses unstable version for latest features and fixes
{ nixpkgs-unstable, ... }:

{
  # Use unstable Tailscale package
  nixpkgs.overlays = [
    (final: prev: {
      tailscale = nixpkgs-unstable.legacyPackages.${prev.system}.tailscale;
    })
  ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Enable subnet routing and exit nodes
  };

  # Trust Tailscale interface (bypass firewall for VPN traffic)
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
