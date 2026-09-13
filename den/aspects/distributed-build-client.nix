{ ... }:
{
  den.aspects.distributed-build-client.nixos = {
    nix.distributedBuilds = true;
    nix.buildMachines = [
      {
        hostName = "coagulation";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 16;
        speedFactor = 10;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        sshUser = "root";
        sshKey = "/etc/nix/build-machine-key";
      }
    ];
    nix.settings.builders-use-substitutes = true;
  };
}
