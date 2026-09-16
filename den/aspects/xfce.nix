{
  den.aspects.xfce.nixos =
    {
      lib,
      pkgs,
      ...
    }:
    {
      services.xserver = {
        enable = lib.mkDefault true;
        desktopManager.xfce.enable = lib.mkDefault true;
        displayManager.lightdm.enable = lib.mkDefault true;

        # disable xfwm4 compositing
        displayManager.sessionCommands = lib.mkDefault ''
          ${pkgs.xfconf}/bin/xfconf-query \
            -c xfwm4 \
            -p /general/use_compositing \
            -n -t bool -s false
        '';
      };

      services.displayManager = {
        defaultSession = lib.mkDefault "xfce";
        autoLogin.enable = lib.mkDefault true;
        autoLogin.user = lib.mkDefault "chris";
      };
    };
}
