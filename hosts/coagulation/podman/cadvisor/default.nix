# cAdvisor - Container metrics exporter for Prometheus
{
  podmanUser,
  podmanGroup,
  lib,
  ...
}:

{
  virtualisation.oci-containers.containers.cadvisor = {
    image = "gcr.io/cadvisor/cadvisor:latest";
    ports = [
      "8080:8080"
    ];
    volumes = [
      "/:/rootfs:ro"
      "/var/run:/var/run:ro"
      "/sys:/sys:ro"
      "/var/lib/containers:/var/lib/containers:ro"
    ];
    extraOptions = [
      "--privileged"
      "--device=/dev/kmsg"
    ];
  };

  # Run as root since cAdvisor needs privileged access to host metrics
  systemd.services.podman-cadvisor.serviceConfig.User = lib.mkForce "root";

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
