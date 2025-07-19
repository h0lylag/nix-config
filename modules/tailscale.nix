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
  services.tailscale.useRoutingFeatures = "both";
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
