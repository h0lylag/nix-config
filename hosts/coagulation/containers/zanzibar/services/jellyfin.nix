{
  config,
  pkgs,
  lib,
  ...
}:

{
  services.jellyfin = {
    enable = true;
    user = "chris";
    group = "users";
    openFirewall = true;
  };
}
