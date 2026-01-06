{
  podmanUser,
  podmanGroup,
  podmanHome,
  pkgs,
  lib,
  ...
}:

{
  virtualisation.oci-containers.containers.airdcpp = {
    image = "gangefors/airdcpp-webclient";
    ports = [
      "5600:5600"
      "5601:5601"
      "21248:21248"
      "21249:21249"
    ];
    volumes = [
      "${podmanHome}/airdcpp:/.airdcpp"
      "/mnt/hdd-pool/main/:/mnt/hdd-pool/main/"
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [
      5600
      5601
      21248
      21249
    ];
    allowedUDPPorts = [
      21248
    ];
  };

  systemd.services.podman-airdcpp.serviceConfig.User = lib.mkForce podmanUser;

  systemd.tmpfiles.rules = [
    "d ${podmanHome}/airdcpp 0700 ${podmanUser} ${podmanGroup} - -"
  ];
}
