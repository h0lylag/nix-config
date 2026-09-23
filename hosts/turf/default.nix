# turf - single-disk BIOS VPS
{ inputs, den, ... }:
{
  den.hosts.x86_64-linux.turf.users.chris = { };

  # Base comes from the host schema; opt into common tooling explicitly.
  den.aspects.turf = {
    includes = [ den.aspects.common ];

    nixos.imports = [
      (
        { ... }:
        {
          imports = [
            ./hardware-configuration.nix
            ./disko.nix
          ];

          boot.loader.grub = {
            enable = true;
          };

          networking.useDHCP = true;

          # Tailscale's recommended UDP forwarding offloads for subnet/exit-node routing.
          systemd.network.links."10-uplink" = {
            matchConfig.MACAddress = "00:16:3e:58:30:11";
            linkConfig = {
              Name = "ens3";
              GenericReceiveOffloadUDPForwarding = true;
              GenericReceiveOffloadList = false;
            };
          };

          boot.kernelParams = [
            "zswap.enabled=1"
            "zswap.max_pool_percent=100"
            "zswap.compressor=zstd"
            "zswap.zpool=zsmalloc"
          ];

          swapDevices = [
            {
              device = "/var/lib/swapfile";
              size = 4 * 1024;
            }
          ];

          system.stateVersion = "26.05";
        }
      )
      inputs.disko.nixosModules.disko
    ];
  };
}
