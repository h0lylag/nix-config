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
    user = "chris";
    group = "users";
    openFirewall = true;
  };
}
