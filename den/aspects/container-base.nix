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
        inputs.sops-nix.nixosModules.sops
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

      users.users.chris = {
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel"
          "media"
        ];
        initialPassword = "chris";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
        ];
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
