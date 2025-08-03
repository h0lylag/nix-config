{
  config,
  pkgs,
  specialArgs,
  ...
}:
let
  unstable = specialArgs.unstable;
  system = pkgs.system;
in
{
  nixpkgs.overlays = [
    (final: prev: {
      tailscale =
        (import unstable {
          inherit system;
          config.allowUnfree = true;
        }).tailscale;
    })
  ];

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both"; # also enables ipv4 and ipv6 net forwarding
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
