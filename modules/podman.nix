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

    # Create a `docker` alias for podman
    dockerCompat = true;

    # Enable DNS for container-to-container name resolution (netavark + aardvark)
    defaultNetwork.settings = {
      dns_enabled = true;
    };

    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  virtualisation.containers.registries.search = [
    "docker.io"
  ];

  environment.systemPackages = with pkgs; [
    podman-compose
    #skopeo
    #dive
  ];
}
