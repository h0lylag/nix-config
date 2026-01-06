{ lib, ... }:

{
  virtualisation.oci-containers.containers.netalertx = {
    image = "ghcr.io/jokob-sk/netalertx:latest";
    autoStart = true;
    extraOptions = [
      "--network=host"
      "--cap-drop=ALL"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
      "--cap-add=NET_BIND_SERVICE"
      "--mount=type=tmpfs,destination=/tmp,tmpfs-mode=1777,chown=true"
    ];
    volumes = [
      "netalertx_data:/data"
      "/etc/localtime:/etc/localtime:ro"
    ];
    environment = {
      PUID = "20211";
      PGID = "20211";
      PORT = "20211";
      GRAPHQL_PORT = "20212";
      SCAN_SUBNETS = "['10.1.1.0/24 --interface=eno1']";
    };
  };

  networking.firewall.allowedTCPPorts = [
    20211
    20214
  ];
}
