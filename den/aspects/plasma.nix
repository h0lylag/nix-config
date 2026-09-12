{
  den.aspects.plasma.nixos =
    { lib, ... }:
    {
      # KDE Plasma Desktop Environment
      services.desktopManager.plasma6.enable = lib.mkDefault true;
      services.displayManager.sddm.enable = lib.mkDefault true;
      services.displayManager.autoLogin.enable = lib.mkDefault true;
      services.displayManager.autoLogin.user = lib.mkDefault "chris";

      # Shell aliases
      environment.shellAliases = {
        plasma-restart = ''
          plasmashell --replace &
        '';
      };

      programs.kde-pim = {
        enable = lib.mkDefault true;
        kmail = lib.mkDefault true;
      };
    };
}
