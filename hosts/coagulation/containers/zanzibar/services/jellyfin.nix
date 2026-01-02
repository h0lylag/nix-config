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
    user = "chris";
    group = "users";
    openFirewall = true;
  };
}
