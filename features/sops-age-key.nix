{
  config,
  lib,
  pkgs,
  ...
}:

{
  sops.age = {
    generateKey = true;
    keyFile = "/var/lib/sops-nix/key.txt";
  };

  # sops-nix only creates its own key-generation step when secrets are
  # configured. Bootstrap the machine key independently so new systems can
  # receive secrets later without a chicken-and-egg setup step.
  system.activationScripts = {
    sops-age-key = {
      deps = [ "specialfs" ];
      text = ''
        key_file=/var/lib/sops-nix/key.txt
        install -d -m 0700 /var/lib/sops-nix
        if [[ ! -f "$key_file" ]]; then
          echo "Generating machine-specific age key..."
          ${pkgs.age}/bin/age-keygen -o "$key_file"
        fi
      '';
    };
  }
  // lib.optionalAttrs (config.sops.secrets != { }) {
    setupSecrets.deps = [ "sops-age-key" ];
  }
  //
    lib.optionalAttrs (lib.any (secret: secret.neededForUsers) (lib.attrValues config.sops.secrets))
      {
        setupSecretsForUsers.deps = [ "sops-age-key" ];
      };
}
