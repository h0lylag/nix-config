{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.sonarr = {
    enable = true;
    package = pkgs.unstable.sonarr;
    user = "sonarr";
    group = "media";
    openFirewall = true;
  };

  systemd.services.sonarr.serviceConfig.UMask = "0002";
}
