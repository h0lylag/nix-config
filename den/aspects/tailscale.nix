{ inputs, ... }:
let
  overlays = import ../../overlays { inherit inputs; };
in
{
  den.aspects.tailscale.nixos =
    # Tailscale aspect - VPN mesh networking
    # Uses unstable version for latest features and fixes
    { ... }:
    {
      # Trayscale and the service both consume pkgs.tailscale.
      nixpkgs.overlays = [ overlays.tailscale ];

      services.tailscale = {
        enable = true;
        useRoutingFeatures = "both"; # Enable subnet routing and exit nodes
      };

      # Trust Tailscale interface (bypass firewall for VPN traffic)
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
    };
}
