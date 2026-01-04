{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.jellyfin = {
    enable = true;
    package = pkgs.unstable.jellyfin;
    user = "jellyfin";
    group = "media";
    openFirewall = true;
  };

  systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
}
