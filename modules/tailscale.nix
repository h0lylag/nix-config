{
  config,
  pkgs,
  specialArgs,
  ...
}:
let
  nixpkgs-unstable = specialArgs.nixpkgs-unstable;
  system = pkgs.system;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      tailscale = nixpkgs-unstable.legacyPackages.${system}.tailscale;
    })
  ];

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both"; # also enables ipv4 and ipv6 net forwarding
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
