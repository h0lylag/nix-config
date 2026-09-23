# midship - Hetzner-cloud VM (OVH datacenter)
{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.midship.users.chris = { };

  den.hosts.x86_64-linux.midship.specialArgs = { inherit (inputs) eve-price-check; };

  den.aspects.midship = {
    includes = [
      den.aspects.common
      den.aspects.distributed-build-client
    ];

    nixos.imports = [
      (
        { pkgs, lib, ... }:

        {
          imports = [
            ./disko.nix
            ./hardware-configuration.nix
            ../../modules/sftp-chroot.nix
            ./web/ssl.nix
            ./web/php.nix
            ./web/nginx.nix
            ./services/eve-fundraiser.nix
            ./services/eve-price-check.nix
            ./services/eve-public-contracts.nix
            ./services/postgresql.nix
            ./services/overseer.nix
          ];

          services.sftpChroot = {
            enable = false;
            users.sven = { };
            passwordAuth = true;
          };

          services.openssh.enable = true;
          services.timesyncd.enable = true;

          swapDevices = [
            {
              device = "/var/lib/swapfile";
              size = 1 * 8192;
            }
          ];

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 100;
            priority = 100;
          };

          boot.kernel.sysctl = {
            "vm.swappiness" = 100;
            "vm.page-cluster" = 0;
          };

          systemd.oomd.enable = true;

          networking = {
            useDHCP = true;

            firewall = {
              enable = true;
              allowedTCPPorts = [
                22
                80
                443
                7777
                8888
                25565
              ];
              allowedUDPPorts = [ 7777 ];
            };
          };

          users.users.nginx = {
            isSystemUser = true;
            group = "nginx";
            extraGroups = [ "log" ];
          };

          # Cloudflare API credentials for ACME DNS-01 validation
          sops.secrets.cloudflare = {
            sopsFile = ../../secrets/cloudflare.env;
            format = "dotenv";
            mode = "0440";
            owner = "root";
            group = "acme";
            path = "/run/secrets/cloudflare";
          };

          system.stateVersion = "25.11";
        }
      )
      inputs.disko.nixosModules.disko
    ];
  };
}
