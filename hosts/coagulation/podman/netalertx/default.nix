{ ... }:

{
  virtualisation.oci-containers.containers.netalertx = {
    image = "ghcr.io/jokob-sk/netalertx:latest";
    extraOptions = [
      "--network=host"
      # The guide recommends these tmpfs settings for internal performance
      "--tmpfs=/tmp:uid=20211,gid=20211,mode=1700"
    ];
    environment = {
      TZ = "America/Los_Angeles";
      PORT = "20211";
      # The guide uses this to prevent port clashing on the host network
      APP_CONF_OVERRIDE = "{\"GRAPHQL_PORT\":\"20214\"}";
    };
    volumes = [
      "/var/lib/podman/netalertx/data:/data:Z"
      "/etc/localtime:/etc/localtime:ro" # Recommended for log sync
    ];
  };
}
