{ inputs, ... }:
{
  den.aspects.tailscale.nixos =
    # Tailscale aspect - VPN mesh networking
    # Uses unstable version for latest features and fixes
    { ... }:
    {
      # Use unstable Tailscale package
      nixpkgs.overlays = [
        (final: prev: {
          tailscale = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.tailscale;
        })
      ];

      services.tailscale = {
        enable = true;
        useRoutingFeatures = "both"; # Enable subnet routing and exit nodes
      };

      # Trust Tailscale interface (bypass firewall for VPN traffic)
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
    };
}
