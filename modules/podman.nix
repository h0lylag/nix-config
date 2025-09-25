{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable common container config files in /etc/containers
  virtualisation.containers.enable = true;

  virtualisation.podman = {
    enable = true;
    # Create a `docker` alias for podman, to use it as a drop-in replacement
    dockerCompat = true;
    # Enable DNS for container-to-container name resolution (netavark + aardvark)
    defaultNetwork.settings = {
      dns_enabled = true;
    };
    # Periodically prune old images/containers
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Common registries for image search
  virtualisation.containers.registries.search = [
    "docker.io"
    "ghcr.io"
    "quay.io"
  ];

  # Helpful tooling
  environment.systemPackages = with pkgs; [
    podman-compose
    skopeo
    dive
  ];
}
