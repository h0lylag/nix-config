# 2401-penitent-tangent - Lenovo ThinkCentre M75q (Ryzen 5 PRO 3400GE)
{ inputs, den, ... }:
{
  den.hosts.x86_64-linux."2401-penitent-tangent".users.chris = { };

  den.aspects."2401-penitent-tangent" = {
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
              address = "10.1.1.34";
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
