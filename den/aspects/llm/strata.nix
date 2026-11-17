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
    # 32K prompt chunks instead of the automatic 8K: on relic fresh prompts
    # of 14K and 54K tokens read 22% and 29% faster, short-prompt decode is
    # unchanged and the answer right after a 14K prompt is 5% slower.
    "--set"
    "prefill=auto:32768"
    # The share of VRAM-cache misses read over PCIe; the CPU pool computes the
    # rest. The gfx11 default 0.55 decoded 4% slower than 0.65 on relic.
    "--set"
    "pcie-frac=0.65"
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
      # Fill the 47 GiB expert arena with O_DIRECT reads; buffered reads leave
      # a second copy of the expert files in the page cache.
      STRATA_UNBUFFERED_LOAD = "1";
      # The exact long-prompt QSA scorer, opt-in on gfx1100. Upstream measured
      # prompts of 131K tokens 10-13% faster and 240K 22% on a 7900 XTX.
      STRATA_SCORES_THREAD = "1";
      # The engine turns these on by default only for gfx12 and gfx1151. They
      # change rounding, but on relic they moved first-token logprobs less
      # than two restarts of the same config, for decode +4.6% and prompts
      # +44-50% (scripts/strata-ab).
      STRATA_EXP_MODE = "8";
      STRATA_HC_Q8 = "1";
      STRATA_PF_FUSED = "1";
      STRATA_HIP_WMMA = "1";
      STRATA_GDN_CHUNKED = "1";
      STRATA_PF_F16 = "1";
      STRATA_PA_FAST = "1";
      STRATA_HC_UPMIX = "1";
      STRATA_PF_GEMM = "1";
      STRATA_PF_PAD = "1";
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
      # Lets the engine lock its 26.8 GiB n-gram (PLE) table in RAM when the
      # conversation cache leaves room, so memory pressure cannot evict it.
      LimitMEMLOCK = "infinity";
      # The GPU reads the expert arena through a KFD userptr. Swapping any of
      # it out evicts the engine's GPU queues, as it did for Maya.
      MemorySwapMax = 0;

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
