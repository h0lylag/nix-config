{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.services.dayzA2SWatchdog;
in
{
  options.services.dayzA2SWatchdog = with lib; {
    enable = mkEnableOption "DayZ A2S watchdog (restart dayz-server if A2S unresponsive)";

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

    restartAfter = mkOption {
      type = types.ints.positive;
      default = 300;
      description = "Seconds without a successful A2S response before restart.";
    };

    service = mkOption {
      type = types.str;
      default = "dayz-server.service";
      description = "Systemd unit to restart when unhealthy.";
    };

    interval = mkOption {
      type = types.str;
      default = "1min";
      description = "How often to run the watchdog.";
      example = "30s";
    };

    stampPath = mkOption {
      type = types.str; # keep as string (paths would be copied to the store)
      default = "/run/dayz-a2s-watchdog/last_ok";
      description = "Where to record the timestamp of the last successful A2S response.";
    };

    quiet = mkOption {
      type = types.bool;
      default = true;
      description = "Suppress OK/MISS logs (still logs RESTART).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.dayz-a2s-watchdog = {
      description = "DayZ A2S watchdog (restart if no response > ${toString cfg.restartAfter}s)";
      after = [ "network-online.target" cfg.service ];
      wants = [ "network-online.target" cfg.service ];

      # <<< key change: use `script` instead of ExecStart >>>
      script = ''
        set -euo pipefail
        exec ${pkgs.python3}/bin/python - \
          --host ${lib.escapeShellArg cfg.host} \
          --port ${toString cfg.port} \
          --timeout ${toString cfg.timeout} \
          --stamp ${lib.escapeShellArg cfg.stampPath} \
          --restart-after ${toString cfg.restartAfter} \
          --service ${lib.escapeShellArg cfg.service} \
          ${lib.optionalString cfg.quiet "--quiet"} <<'PY'
    import argparse, socket, struct, time, os, subprocess, sys
    HDR = b"\xFF\xFF\xFF\xFF"
    A2S_INFO = HDR + b"TSource Engine Query\x00"
    RESP_INFO = 0x49
    RESP_CHALLENGE = 0x41
    def a2s_ok(host: str, port: int, timeout: float) -> bool:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.settimeout(timeout)
            try:
                s.sendto(A2S_INFO, (host, port))
                pkt, _ = s.recvfrom(4096)
            except socket.timeout:
                return False
            if len(pkt) < 5 or pkt[:4] != HDR:
                return False
            t = pkt[4]
            if t == RESP_INFO:
                return True
            if t == RESP_CHALLENGE and len(pkt) >= 9:
                chall = struct.unpack_from("<i", pkt, 5)[0]
                s.sendto(A2S_INFO + struct.pack("<i", chall), (host, port))
                try:
                    pkt2, _ = s.recvfrom(4096)
                except socket.timeout:
                    return False
                return len(pkt2) >= 5 and pkt2[:4] == HDR and pkt2[4] == RESP_INFO
            return False
    def read_stamp(path: str) -> float:
        try:
            with open(path, "r") as f:
                return float(f.read().strip())
        except Exception:
            return 0.0
    def write_stamp(path: str, ts: float) -> None:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(str(ts))
    def maybe_restart(service: str) -> int:
        return subprocess.call(["systemctl", "restart", service])
    def main() -> int:
        ap = argparse.ArgumentParser(description="DayZ A2S watchdog")
        ap.add_argument("--host", default="127.0.0.1")
        ap.add_argument("--port", type=int, default=27016)
        ap.add_argument("--timeout", type=float, default=2.5)
        ap.add_argument("--stamp", default="/run/dayz-a2s-watchdog/last_ok")
        ap.add_argument("--restart-after", type=int, default=300)
        ap.add_argument("--service", default="dayz-server.service")
        ap.add_argument("--quiet", action="store_true")
        args = ap.parse_args()
        now = time.time()
        ok = a2s_ok(args.host, args.port, args.timeout)
        if ok:
            write_stamp(args.stamp, now)
            if not args.quiet:
                print(f"OK: {args.host}:{args.port} responded")
            return 0
        last_ok = read_stamp(args.stamp)
        gap = now - last_ok if last_ok > 0 else 1e9
        if gap >= args.restart_after:
            rc = maybe_restart(args.service)
            print(f"RESTART: no A2S response for {int(gap)}s (>= {args.restart_after}s). Restarted {args.service} (rc={rc}).")
            write_stamp(args.stamp, now)
            return 1
        if not args.quiet:
            print(f"MISS: no A2S response; last OK {int(gap)}s ago (< {args.restart_after}s), holding off.")
        return 2
    if __name__ == "__main__":
        sys.exit(main())
    PY
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RuntimeDirectory = "dayz-a2s-watchdog";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        # allow writing the stamp directory
        ReadWritePaths = [ (builtins.dirOf cfg.stampPath) ];
      };
    };

    systemd.timers.dayz-a2s-watchdog = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.interval;
        OnUnitActiveSec = cfg.interval;
        RandomizedDelaySec = "15s";
        AccuracySec = "1s";
      };
    };
}
