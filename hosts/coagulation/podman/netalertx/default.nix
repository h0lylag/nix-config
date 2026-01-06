{
  podmanUser,
  podmanHome,
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
      # No PUID/PGID - Let internal root map to host podman user
      TZ = "America/Los_Angeles";
      PORT = "20211";
    };
    volumes = [
      # Lowercase :z is often more successful for shared rootless mounts
      "${podmanHome}/netalertx/data:/data:z"
    ];
  };

  systemd.services.podman-netalertx.serviceConfig.User = lib.mkForce podmanUser;
}
