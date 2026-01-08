{ pkgs, ... }:

let
  image = "ghcr.io/audionut/upload-assistant:latest";
  configDir = "/var/lib/upload-assistant";

  # Wrapper script to run the container interactively
  upload-assistant = pkgs.writeShellScriptBin "upload-assistant" ''
    # Ensure config directory exists
    if [ ! -d "${configDir}" ]; then
      echo "Creating config directory at ${configDir}..."
      sudo mkdir -p "${configDir}"
      sudo chown $(id -u):$(id -g) "${configDir}"
    fi

    # Check if config file exists
    if [ ! -f "${configDir}/config.env" ] && [ ! -f "${configDir}/config.yaml" ] && [ ! -f "${configDir}/config.py" ]; then
      echo "Warning: No configuration file found in ${configDir}."
      echo "Please place your config.py/config.yaml/config.env in ${configDir}."
    fi

    echo "Starting Upload-Assistant..."
    # Run the container
    # --network=host is recommended by docs
    # Binding /config to the persistent directory
    # Binding media paths
    ${pkgs.podman}/bin/podman run --rm -it \
      --network=host \
      -v "${configDir}:/Upload-Assistant/data" \
      -v "/mnt/hdd-pool/main:/mnt/hdd-pool/main" \
      -v "/mnt/nvme-pool/scratch:/mnt/nvme-pool/scratch" \
      -v "/etc/localtime:/etc/localtime:ro" \
      ${image} \
      "$@"
  '';

  # Wrapper for config generator
  upload-assistant-config-generator = pkgs.writeShellScriptBin "upload-assistant-config-generator" ''
    # Ensure config directory exists
    if [ ! -d "${configDir}" ]; then
      echo "Creating config directory at ${configDir}..."
      sudo mkdir -p "${configDir}"
      sudo chown $(id -u):$(id -g) "${configDir}"
    fi

    echo "Starting Upload-Assistant Config Generator..."
    ${pkgs.podman}/bin/podman run --rm -it \
      --network=host \
      -v "${configDir}:/Upload-Assistant/data" \
      -v "/mnt/hdd-pool/main:/mnt/hdd-pool/main" \
      -v "/mnt/nvme-pool/scratch:/mnt/nvme-pool/scratch" \
      -v "/etc/localtime:/etc/localtime:ro" \
      --entrypoint python \
      ${image} \
      /Upload-Assistant/config-generator.py
  '';
in
{
  environment.systemPackages = [
    upload-assistant
    upload-assistant-config-generator
  ];

  # Ensure the config directory exists with appropriate permissions
  systemd.tmpfiles.rules = [
    "d ${configDir} 0775 root media - -"
  ];
}
