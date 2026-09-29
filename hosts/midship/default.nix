# midship - OVH/OpenStack VPS (formerly Ascension), public edge and applications.
{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.midship.users.chris = { };
  den.hosts.x86_64-linux.midship.specialArgs = { inherit (inputs) eve-price-check; };

  den.aspects.midship = {
    includes = [ den.aspects.common ];

    nixos.imports = [
      (
        { ... }:
        {
          imports = [
            ./hardware-configuration.nix
            ./disko.nix
            ./web/ssl.nix
            ./web/wordpress.nix
            ./web/php.nix
            ./web/nginx.nix
            ./services/postgresql.nix
            ./services/eve-price-check.nix
            ./services/eve-public-contracts.nix
            ./services/overseer.nix
          ];

          networking = {
            useNetworkd = true;
            useDHCP = false;
            firewall.allowedTCPPorts = [
              80
              443
              7777
              8888
              25565
            ];
            firewall.allowedUDPPorts = [ 7777 ];
          };

          # Tailscale's recommended UDP forwarding offloads for subnet/exit-node routing.
          systemd.network.links."10-uplink" = {
            matchConfig.MACAddress = "fa:16:3e:64:18:62";
            linkConfig = {
              Name = "ens3";
              GenericReceiveOffloadUDPForwarding = true;
              GenericReceiveOffloadList = false;
            };
          };

          # Preserve the provider's DHCP-supplied /32 address, gateway route and DNS.
          systemd.network.networks."10-uplink" = {
            matchConfig.MACAddress = "fa:16:3e:64:18:62";
            linkConfig.MTUBytes = "1500";
            networkConfig = {
              DHCP = "yes";
              IPv6AcceptRA = true;
            };
            # Keep the declared host name instead of the provider's old name.
            dhcpV4Config.UseHostname = false;
            dhcpV6Config.UseHostname = false;
          };
          services.resolved.enable = true;

          # The base profile supplies root/chris authorized keys and enables Tailscale.
          services.openssh.settings.PasswordAuthentication = false;

          swapDevices = [
            {
              device = "/var/lib/swapfile";
              size = 8 * 1024;
              priority = 10;
            }
          ];

          zramSwap = {
            enable = true;
            algorithm = "zstd";
            memoryPercent = 100;
            priority = 100;
          };

          users.users.nginx.extraGroups = [ "log" ];
          sops.secrets.cloudflare = {
            sopsFile = ../../secrets/cloudflare.env;
            format = "dotenv";
            mode = "0440";
            owner = "root";
            group = "acme";
            path = "/run/secrets/cloudflare";
          };

          system.stateVersion = "26.05";
        }
      )
      inputs.disko.nixosModules.disko
    ];
  };
}
