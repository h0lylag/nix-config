{
  podmanUser,
  podmanGroup,
  podmanHome,
  ...
}:

{
  virtualisation.oci-containers.containers.netalertx = {
    image = "jokobsk/netalertx:latest";
    user = podmanUser;
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

  systemd.tmpfiles.rules = [
    "d ${podmanHome}/netalertx 0700 ${podmanUser} ${podmanGroup} - -"
  ];
}
