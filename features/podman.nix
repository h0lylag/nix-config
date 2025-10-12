# Podman feature - Docker-compatible container runtime
{ pkgs, ... }:

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
  virtualisation.containers.registries.search = [ "docker.io" ];

  environment.systemPackages = [ pkgs.podman-compose ];
}
