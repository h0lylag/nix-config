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
    extraOptions = [ "--network=host" ];
    environment = {
      PUID = "0";
      PGID = "0";
      TZ = "America/Los_Angeles";
      PORT = "20211";
    };
    volumes = [
      "${podmanHome}/netalertx/data:/data"
      "/etc/localtime:/etc/localtime:ro"
    ];
  };

  systemd.services.podman-netalertx.serviceConfig.User = lib.mkForce podmanUser;

  systemd.tmpfiles.rules = [
    "d ${podmanHome}/netalertx 0700 ${podmanUser} ${podmanGroup} - -"
  ];
}
