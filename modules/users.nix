{ config, pkgs, ... }: {
  users.users.chris = {
    isNormalUser = true;
    description = "Chris";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "chris";
}
