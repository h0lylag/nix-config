{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.sonarr = {
    enable = true;
    user = "chris";
    group = "users";
    openFirewall = true;
  };
}
