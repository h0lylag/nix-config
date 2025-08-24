{
  config,
  lib,
  pkgs,
  ...
}:

{
  systemd.services.dayz-a2s-watchdog = {
    description = "DayZ A2S watchdog (restart dayz-server.service if no response > 5 minutes)";
    after = [
      "network-online.target"
      "dayz-server.service"
    ];
    wants = [
      "network-online.target"
      "dayz-server.service"
    ];

    # We embed the Python directly via a here-doc fed to python's stdin.
    script = ''
            set -euo pipefail
            exec ${pkgs.python3}/bin/python - \
              --host gemini.gravemind.sh \
              --port 27016 \
              --timeout 2.5 \
              --stamp /run/dayz-a2s-watchdog/last_ok \
              --restart-after 300 \
              --service dayz-server.service \
              --quiet <<'PY'
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
          ap.add_argument("--host", default="gemini.gravemind.sh")
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
              write_stamp(args.stamp, now)  # avoid immediate re-restart loop
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
      ReadWritePaths = [ "/run/dayz-a2s-watchdog" ];
      NoNewPrivileges = true;
    };
  };

  systemd.timers.dayz-a2s-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
      RandomizedDelaySec = "15s";
      AccuracySec = "1s";
    };
  };
}
