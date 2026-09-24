{ ... }:
{
  den.aspects.tailscale.nixos =
    # Tailscale aspect - VPN mesh networking
    # Uses unstable version for latest features and fixes
    { ... }:
    {
      # Trayscale and the service both consume pkgs.tailscale.
      nixpkgs.overlays = [ (final: _prev: { tailscale = final.unstable.tailscale; }) ];

      services.tailscale = {
        enable = true;
        useRoutingFeatures = "both"; # Enable subnet routing and exit nodes
      };

      # Trust Tailscale interface (bypass firewall for VPN traffic)
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
    };
}
