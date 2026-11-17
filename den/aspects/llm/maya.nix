{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8099;
  stateDir = "/var/lib/maya";
  maya = pkgs.local.maya;
  # The first start downloads and sets up GLM-5.3-Flash Maya-S24 (95 GB).
  # --model makes every start run the setup again, which takes a second once
  # the model is in place, so changes here apply on the next start.
  args = [
    "--backend"
    "hip"
    "--gpu"
    "0"
    "--model"
    "glm-maya-s24"
    "--context"
    "262144"
    # The desktop and open apps use about 2 GiB of VRAM. When they need more
    # than is free, amdgpu moves Maya's VRAM pool into RAM the tier already
    # holds, and the system locks up. Games need Maya stopped.
    "--vram-reserve-mib"
    "4096"
    "--yes"
    "--download-model"
    "--plain"
    # The server binds IPv4 only. Like llama-server, it has no API key and
    # the firewall limits it to the tailnet.
    "--host"
    "0.0.0.0"
    "--port"
    (toString port)
  ];

  # ROCm advises its pinned host memory for huge pages. Each khugepaged
  # collapse in Maya's RAM tier makes amdgpu evict Maya's GPU queues and
  # refetch the allocation, stalling decode for seconds. PR_SET_THP_DISABLE
  # (41) survives fork and exec, so THP stays on for everything else.
  thpOff = pkgs.writers.writePython3 "thp-off" { } ''
    import ctypes
    import os
    import sys

    if ctypes.CDLL(None, use_errno=True).prctl(41, 1, 0, 0, 0) != 0:
        sys.exit("thp-off: prctl: " + os.strerror(ctypes.get_errno()))
    os.execvp(sys.argv[1], sys.argv[1:])
  '';

  # Runs Maya by hand (--setup, --bench, --report) against the service's
  # instance, as its user and with its environment and limits. It stops the
  # service and the other model servers first, since they share the GPU.
  admin = pkgs.writeShellScriptBin "maya-admin" ''
    exec /run/wrappers/bin/sudo ${config.systemd.package}/bin/systemd-run \
      --quiet --pty --wait --collect --service-type=exec \
      --unit=maya-admin \
      --property=User=maya --property=Group=maya \
      --property=LimitMEMLOCK=infinity \
      --property=MemorySwapMax=0 \
      --property=Conflicts=maya.service \
      --property=Conflicts=llama-cpp.service \
      --property=Conflicts=strata.service \
      --working-directory=${stateDir} \
      ${
        lib.concatMapAttrsStringSep " " (
          name: value: lib.escapeShellArg "--setenv=${name}=${value}"
        ) config.systemd.services.maya.environment
      } \
      ${thpOff} ${lib.getExe maya} "$@"
  '';
in
{
  users = {
    users.maya = {
      isSystemUser = true;
      group = "maya";
      home = stateDir;
      extraGroups = [
        "render"
        "video"
      ];
    };
    groups.maya = { };
  };

  environment.systemPackages = [ admin ];

  systemd.services.maya = {
    description = "Project Maya inference server";
    # Maya, Strata and llama-server each want the whole GPU, so starting one
    # stops the others.
    conflicts = [
      "llama-cpp.service"
      "strata.service"
    ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # The setup downloads models with curl when it can.
    path = [ pkgs.curl ];
    environment = {
      HOME = stateDir;
      MAYA_HOME = stateDir;
      # Without a cap the RAM tier takes whatever is free at start. Each size
      # class stops at the experts VRAM does not hold plus spares, so a cap
      # above Maya-S24's need costs nothing (68 left 21 on the SSD). The
      # engine uses about 10 GB more.
      MAYA_GLM_RAM_GB = "70";
      # Pin in 1 GB pieces, as Maya does on Windows: amdgpu refetches, and
      # Maya retries, a pinned allocation whole.
      MAYA_GLM_PIN_PIECE_MB = "1024";
    };
    serviceConfig = {
      ExecStart = "${thpOff} ${lib.getExe maya} ${lib.escapeShellArgs args}";
      SyslogIdentifier = "maya";
      # Maya waits up to 150 s for the request in progress and the engine's
      # save of its conversation.
      TimeoutStopSec = 180;
      LimitMEMLOCK = "infinity";
      # Swapping out the pinned tier evicts the GPU queues, as a huge-page
      # collapse does.
      MemorySwapMax = 0;

      User = "maya";
      Group = "maya";
      StateDirectory = "maya";
      StateDirectoryMode = "0700";
      NoNewPrivileges = true;
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
