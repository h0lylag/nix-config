{
  lib,
  pkgs,
  config,
  ...
}:

let
  # Use your local dayz-tools package that provides a2s-info
  dayz-tools = pkgs.callPackage ../../../pkgs/dayz-tools/default.nix { };
  a2sCli = "${dayz-tools.a2s-info}/bin/a2s-info";

  cfg = config.services.dayzA2SWatchdog;

  checkScript = pkgs.writeShellScript "dayz-a2s-healthcheck" ''
    set -euo pipefail

    HOST=${lib.escapeShellArg cfg.host}
    PORT=${toString cfg.port}
    TIMEOUT=${toString cfg.timeout}
    QUIET=${if cfg.quiet then "1" else ""}

    # Always use JSON and inspect .ok
    A2S_JSON_CMD="${a2sCli} --host \"$HOST\" --port \"$PORT\" --timeout \"$TIMEOUT\" --json"

    # State lives under the systemd RuntimeDirectory
    STATE_DIR="${RUNTIME_DIRECTORY: -/run/dayz-a2s-watchdog}"
    FAILS_FILE="$STATE_DIR/fails"
    LASTOK_FILE="$STATE_DIR/last_ok"
    COOLDOWN_FILE="$STATE_DIR/cooldown_until"

    FAILS_BEFORE_RESTART=${toString cfg.failsBeforeRestart}
    GRACE_SEC=${toString cfg.cooldownSeconds}

    now() { ${pkgs.coreutils}/bin/date +%s; }
    mkdir -p "$STATE_DIR"

    # If we're in a cooldown, quietly succeed (avoid retriggering while server boots)
    if [ -f "$COOLDOWN_FILE" ]; then
      until_ts="$(${pkgs.coreutils}/bin/cat "$COOLDOWN_FILE" || echo 0)"
      if [ "$(now)" -lt "$until_ts" ]; then
        # optional noisy log:
        [ -z "$QUIET" ] || true
        exit 0
      else
        ${pkgs.coreutils}/bin/rm -f "$COOLDOWN_FILE" || true
      fi
    fi

    # Run A2S and decide health from JSON .ok
    OUT="$(${pkgs.bash}/bin/bash -lc "$A2S_JSON_CMD" 2>/dev/null || true)"

    is_ok() {
      # Try jq (robust), fall back to grep if jq somehow unavailable
      if ${pkgs.jq}/bin/jq -e '.ok==true' >/dev/null 2>&1 <<<"$OUT"; then
        return 0
      else
        echo "$OUT" | ${pkgs.gnugrep}/bin/grep -q '"ok"[[:space:]]*:[[:space:]]*true'
      fi
    }

    if is_ok; then
      ${pkgs.coreutils}/bin/date +%s > "$LASTOK_FILE"
      echo 0 > "$FAILS_FILE"
      [ -z "$QUIET" ] || true
      exit 0
    else
      old=0
      [ -f "$FAILS_FILE" ] && old="$(${pkgs.coreutils}/bin/cat "$FAILS_FILE" || echo 0)"
      new=$(( old + 1 ))
      echo "$new" > "$FAILS_FILE"

      if [ "$new" -lt "$FAILS_BEFORE_RESTART" ]; then
        [ -z "$QUIET" ] && echo "watchdog: miss ${new}/${FAILS_BEFORE_RESTART}" >&2 || true
        exit 0
      fi

      # Threshold reached: arm cooldown and fail once to trigger OnFailure recovery
      until_ts=$(( $(now) + GRACE_SEC ))
      echo "$until_ts" > "$COOLDOWN_FILE"
      echo 0 > "$FAILS_FILE"
      echo "watchdog: threshold reached → triggering recovery; cooldown ${GRACE_SEC}s" >&2
      exit 1
    fi
  '';
in
{
  options.services.dayzA2SWatchdog = with lib; {
    enable = mkEnableOption "DayZ A2S watchdog (oneshot + timer with N-of-fails & cooldown)";

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "A2S host/IP to query.";
    };

    port = mkOption {
      type = types.port;
      default = 27016;
      description = "A2S (Steam query) port.";
    };

    timeout = mkOption {
      type = types.float;
      default = 2.5;
      description = "Per-attempt A2S timeout in seconds.";
    };

    failsBeforeRestart = mkOption {
      type = types.ints.positive;
      default = 3;
      description = "Consecutive failures required before triggering a restart.";
    };

    cooldownSeconds = mkOption {
      type = types.ints.positive;
      default = 180;
      description = "Cooldown (skip checks) after a triggered restart.";
    };

    interval = mkOption {
      type = types.str;
      default = "30s";
      description = "How often to run the healthcheck timer.";
      example = "15s";
    };

    quiet = mkOption {
      type = types.bool;
      default = true;
      description = "Suppress OK/MISS logs (still logs threshold/recovery).";
    };

    service = mkOption {
      type = types.str;
      default = "dayz-server.service";
      description = "Target systemd unit to restart on failure (used by recovery template).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Healthcheck oneshot service (does NOT restart anything directly)
    systemd.services.dayz-a2s-watchdog = {
      description = "DayZ A2S healthcheck (oneshot with N-of-fails & cooldown)";
      unitConfig = {
        OnFailure = [ "dayz-recover@${cfg.service}" ];
        After = [
          cfg.service
          "network-online.target"
        ];
        Wants = [
          cfg.service
          "network-online.target"
        ];
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = checkScript;

        # Provide a writable runtime dir for state (fails/cooldown/last_ok)
        RuntimeDirectory = "dayz-a2s-watchdog";

        # Hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        LockPersonality = true;
      };
    };

    # Periodic timer to run the healthcheck
    systemd.timers.dayz-a2s-watchdog = {
      description = "Run DayZ A2S healthcheck periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10s"; # first run soon after boot
        OnUnitActiveSec = cfg.interval; # periodic cadence
        RandomizedDelaySec = "5s";
        AccuracySec = "1s";
        Persistent = true;
      };
    };

    # Generic recovery template: restarts %i once when healthcheck fails
    systemd.services."dayz-recover@" = {
      description = "Restart %i when a DayZ A2S healthcheck fails";
      unitConfig = {
        # Throttle recovery attempts within a window to avoid flapping
        StartLimitIntervalSec = 600;
        StartLimitBurst = 3;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart %i";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        LockPersonality = true;
      };
    };
  };
}
