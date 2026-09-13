# warlock - Oracle Cloud free tier VM
# x86_64, UEFI, single disk
{ den, ... }:
{
  den.hosts.x86_64-linux.warlock.users.chris = { };

  den.aspects.warlock = {
    includes = [
      den.aspects.distributed-build-client
    ];

    nixos.imports = [
      (
        { pkgs, lib, ... }:
        {
          imports = [
            ./hardware-configuration.nix
          ];

          services.openssh.enable = true;

          networking = {
            useDHCP = false;
            interfaces.ens3 = {
              useDHCP = true;
              mtu = 9000;
            };
            firewall.allowedTCPPorts = [ 22 ];
          };

          swapDevices = [
            {
              device = "/var/lib/swapfile";
              size = 8 * 1024;
            }
          ];

          zramSwap = {
            enable = true;
            algorithm = "lz4";
            memoryPercent = 50;
            priority = 100;
          };

          programs.java.enable = lib.mkForce false;
          programs.nix-ld.enable = lib.mkForce false;

          system.stateVersion = "25.11";
        }
      )
    ];
  };
}
