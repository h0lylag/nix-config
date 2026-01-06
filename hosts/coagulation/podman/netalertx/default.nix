{
  podmanUser,
  podmanGroup,
  podmanHome,
  pkgs,
  lib,
  ...
}:

{
  virtualisation.oci-containers.containers.netalertx = {
    image = "jokobsk/netalertx:latest";
    extraOptions = [
      "--network=host"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
      # Disable labeling to prevent ZFS/SELinux permission friction
      "--security-opt=label=disable"
    ];
    environment = {
      # No PUID/PGID here - let it run as internal root
      TZ = "America/Los_Angeles";
      PORT = "20211";
    };
    volumes = [
      # Lowercase :z is often more successful for shared rootless mounts
      "${podmanHome}/netalertx/data:/data:z"
      "/etc/localtime:/etc/localtime:ro"
    ];
  };

  systemd.services.podman-netalertx.serviceConfig.User = lib.mkForce podmanUser;

  systemd.tmpfiles.rules = [
    "d ${podmanHome}/netalertx 0700 ${podmanUser} ${podmanGroup} - -"
    "d ${podmanHome}/netalertx/data 0700 ${podmanUser} ${podmanGroup} - -"
  ];
}
