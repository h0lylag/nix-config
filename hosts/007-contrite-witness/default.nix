# 007-contrite-witness - Lenovo ThinkCentre M75q (Ryzen 5 PRO 3400GE)
{ inputs, den, ... }:
{
  den.hosts.x86_64-linux."007-contrite-witness".users.chris = { };

  den.aspects."007-contrite-witness" = {
    includes = [ den.aspects.m75q ];
    nixos.imports = [
      (
        { ... }:
        {
          imports = [
            ./hardware-configuration.nix
            ./disko.nix
          ];

          networking.interfaces.enp2s0f0.ipv4.addresses = [
            {
              address = "10.1.1.32";
              prefixLength = 24;
            }
          ];

          system.stateVersion = "26.05";
        }
      )
      inputs.disko.nixosModules.disko
    ];
  };
}
