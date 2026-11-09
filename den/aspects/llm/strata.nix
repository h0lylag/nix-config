{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8081;
  stateDir = "/var/lib/strata";
  strata = pkgs.local.strata;
  # Qwen3.8-Flash-Next from ISTA-DASLab. IQ3_S keeps every expert and has the
  # best quality of the four sizes: about 55 GB of RAM plus VRAM once loaded,
  # and an 84 GB download on first start.
  launchArgs = [
    "--family"
    "qwen"
    "--model"
    "iq3_s"
    # Explicit, so it overrides the folder an earlier run saved.
    "--data-dir"
    "${stateDir}/Strata-data"
    # One slot, like llama-server: each extra slot takes VRAM from the
    # expert cache.
    "--parallel"
    "1"
    "--context"
    "256k"
    # The picture reader is a separate engine binary that this build lacks.
    "--vision"
    "off"
    # The desktop and games share this GPU. At the default 700 MiB margin
    # amdgpu starts moving their memory into system RAM and KWin stutters.
    "--set"
    "vram-reserve-mib=4096"
    # Like llama-server, reachable only over the tailnet and unauthenticated.
    "--no-api-key"
    "--access"
    "tailscale"
    "--port"
    (toString port)
    "--yes"
    "--no-tui"
  ];
in
{
  # A real account, not DynamicUser: Strata refuses model folders inside
  # system paths such as /var/lib unless they sit under the user's own home,
  # and a dynamic user's /var/lib/strata is a symlink into /var/lib/private.
  users = {
    users.strata = {
      isSystemUser = true;
      group = "strata";
      home = stateDir;
      extraGroups = [
        "render"
        "video"
      ];
    };
    groups.strata = { };
  };

  systemd.services.strata = {
    description = "Strata inference server";
    # Not enabled at boot: Strata and llama-server both want the whole GPU, so
    # starting either stops the other.
    conflicts = [ "llama-cpp.service" ];
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [ "network-online.target" ];
    # `--access tailscale` runs the tailscale CLI to find the tailnet address.
    path = [ config.services.tailscale.package ];
    environment = {
      HOME = stateDir;
      # A hand-built engine has no hipBLASLt tuning table of its own. This one
      # was calibrated on a 7900 XTX for hipBLASLt 1.2.2, the version this
      # package links; it speeds up prompt processing but rounds differently
      # from plain hipBLAS.
      STRATA_HIPBLASLT_TUNING = "${strata}/share/strata/tools/hip/gfx1100-hipblaslt-100202.txt";
      STRATA_INSTALL_DIR = "${stateDir}/install";
    };
    serviceConfig = {
      # `strata launch` downloads the model, starts the server as a child
      # process and returns, so the unit stays active until stop kills the
      # child through the cgroup.
      Type = "oneshot";
      RemainAfterExit = true;
      # Model preparation needs llama.cpp's gguf-py in the install directory,
      # which Strata would otherwise download.
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${stateDir}/install/third_party"
        "${pkgs.coreutils}/bin/ln -sfn ${strata.llamaCpp} ${stateDir}/install/third_party/llama.cpp"
      ];
      ExecStart = "${lib.getExe strata} launch ${lib.escapeShellArgs launchArgs}";
      ExecStop = "${lib.getExe strata} launch --stop";
      # The first start downloads tens of gigabytes.
      TimeoutStartSec = "infinity";

      User = "strata";
      Group = "strata";
      StateDirectory = "strata";
      StateDirectoryMode = "0700";
      NoNewPrivileges = true;
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

}
