{ lib, ... }:

{
  virtualisation.oci-containers.containers.netalertx = {
    image = "ghcr.io/jokob-sk/netalertx:latest";
    autoStart = true;
    extraOptions = [
      "--network=host"
      # Security: Drop all privileges, then add back only what's required
      "--cap-drop=ALL"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
      "--cap-add=NET_BIND_SERVICE"
      "--cap-add=CHOWN"
      "--cap-add=SETUID"
      "--cap-add=SETGID"
      # Use the robust --mount syntax for the developer's tmpfs requirement
      "--mount=type=tmpfs,destination=/tmp,tmpfs-mode=1700"
    ];
    volumes = [
      # NAMED VOLUME: No more ZFS SQLite locking bugs.
      # Podman manages this in /var/lib/containers/storage/volumes/
      "netalertx_data:/data"
      "/etc/localtime:/etc/localtime:ro"
    ];
    environment = {
      # Aligning with the image's service user
      PUID = "20211";
      PGID = "20211";
      PORT = "20211";
      # Developer recommended override to avoid port clashing
      APP_CONF_OVERRIDE = "{\"GRAPHQL_PORT\":\"20214\"}";
    };
  };

  # Open the ports on your host firewall
  networking.firewall.allowedTCPPorts = [
    20211
    20214
  ];
}
