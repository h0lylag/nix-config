{
  den.aspects.podman.nixos =
    { pkgs, options, ... }:

    {
      virtualisation = {
        containers.enable = true;

        podman = {
          enable = true;
          dockerCompat = true; # Create `docker` alias for compatibility

          # DNS for container name resolution
          defaultNetwork.settings.dns_enabled = true;

          autoPrune = {
            enable = true;
            dates = "weekly";
          };
        };
      };

      # Default container registry
      virtualisation.containers.registries =
        if options.virtualisation.containers.registries ? settings then
          {
            # Preserve the existing registries.conf contents on newer nixpkgs.
            settings.registries = {
              search.registries = [ "docker.io" ];
              insecure.registries = [ ];
              block.registries = [ ];
            };
          }
        else
          {
            # Stable nixpkgs still uses the original registry options.
            search = [ "docker.io" ];
          };

      environment.systemPackages = [ pkgs.podman-compose ];
    };
}
