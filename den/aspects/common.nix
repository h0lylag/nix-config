{ inputs, ... }:
{
  den.aspects.common.nixos =
    # Common aspect - Extended tooling for all managed hosts
    {
      config,
      lib,
      pkgs,
      ...
    }:

    {
      imports = [
        inputs.determinate-nix.nixosModules.default
      ];

      # Nix settings
      nix.settings = {

        # 0 uses all available cores; 1 is serial
        eval-cores = lib.mkDefault 0;

        experimental-features = [
          "nix-command"
          "flakes"
          "parallel-eval"
        ];
        auto-optimise-store = true;
      };

      # Essential programs
      programs.java.enable = true;
      programs.nix-ld.enable = true; # Allow use of dynamically linked binaries

      # Extended system packages
      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
        smartmontools
        nfs-utils
        parted
        comma
      ];

    };
}
