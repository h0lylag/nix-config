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
  # Pull in tailscale from unstable
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
}
