{ inputs, den, ... }:
{
  den.aspects.container-base.nixos =
    {
      config,
      pkgs,
      lib,
      ...
    }:

    {
      # Timezone and locale
      time.timeZone = "America/Los_Angeles";
      i18n.defaultLocale = "en_US.UTF-8";

      # Unstable overlay
      nixpkgs.overlays = [
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            system = pkgs.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
        })
      ];

      imports = [
        den.aspects.tailscale.nixos
        den.aspects.sops-age-key.nixos
      ];

      # Networking basics
      networking.defaultGateway = "10.1.1.1";
      networking.useHostResolvConf = lib.mkForce false;
      networking.nameservers = [
        "10.1.1.8"
      ];

      # Enable SSH
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "prohibit-password";
        settings.PasswordAuthentication = true;
      };

      # User configuration
      users.groups.media = {
        gid = 1300;
      };

      users.users.chris = { ... }: {
        # Containers have their own NixOS evaluation, outside Den user routing.
        imports = [ (den.lib.aspects.resolve "user" den.aspects.chris) ];
        extraGroups = [ "media" ];
      };

      # Basic packages
      environment.systemPackages = with pkgs; [
        htop
        nano
        wget
        curl
        fastfetch
      ];

      # Firewall
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [
        22
      ];
      networking.firewall.allowedUDPPorts = [ ];

      system.stateVersion = "25.11";
    };
}
