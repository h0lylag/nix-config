{ config, lib, pkgs, ... }:

let
  # 1) No-deps A2S health checker (UDP to Steam query port)
  a2sHealthcheck = pkgs.writeScriptBin "a2s_healthcheck.py" ''
    #!${pkgs.python3}/bin/python3
    import socket, os, sys
    HOST = os.environ.get("DAYZ_QUERY_HOST", "127.0.0.1")
    PORT = int(os.environ.get("DAYZ_QUERY_PORT", "27016"))  # adjust if you use a non-default query port
    TIMEOUT = float(os.environ.get("DAYZ_QUERY_TIMEOUT", "2.0"))
    QUERY = b"\xFF\xFF\xFF\xFFTSource Engine Query\x00"
    def healthy():
      try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(TIMEOUT)
        s.sendto(QUERY, (HOST, PORT))
        data, _ = s.recvfrom(4096)
        return len(data) >= 5 and data[:4] == b"\xFF\xFF\xFF\xFF" and data[4] in (0x49, 0x41)
      except Exception:
        return False
      finally:
        try: s.close()
        except: pass
    sys.exit(0 if healthy() else 1)
  '';

  # 2) Long-running notifier that only pings systemd while health is OK
  dayzWatchdogNotify = pkgs.writeShellScriptBin "dayz-watchdog-notify" ''
    #!/usr/bin/env bash
    set -euo pipefail

    HEALTH="${a2sHealthcheck}/bin/a2s_healthcheck.py"
    INTERVAL="${DAYZ_HEALTH_INTERVAL:-5}"       # seconds between checks (fallback if no WATCHDOG_USEC)
    FAIL_MAX="${DAYZ_HEALTH_FAIL_MAX:-3}"       # consecutive failures before we stop pinging
    START_DELAY="${DAYZ_HEALTH_START_DELAY:-10}"# give server time to bind ports on boot

    # only run inside the unit cgroup; exit on stop
    trap 'exit 0' TERM INT

    sleep "$START_DELAY"

    # Use half of systemd's watchdog window if available
    if [[ -n "${WATCHDOG_USEC:-}" ]]; then
      INTERVAL=$(( WATCHDOG_USEC / 2 / 1000000 ))
      [[ $INTERVAL -lt 1 ]] && INTERVAL=1
    fi

    fails=0
    while : ; do
      if "$HEALTH" ; then
        fails=0
        ${pkgs.systemd}/bin/systemd-notify --watchdog || true
      else
        ((fails++))
        # After N failures, stop notifying; systemd watchdog will expire and restart the unit
        if (( fails >= FAIL_MAX )); then
          echo "dayz-watchdog: health failed ${fails}x; stopping notifications"
          # fall through and just sleep without notifying; watchdog will trip
        fi
      fi
      sleep "$INTERVAL"
    done
  '';
in
{
  # --- your existing block stays as-is ---
  services.dayz-server = {
    enable = true;
    user = "dayz";
    group = "users";
    steamLogin = "the_h0ly_christ";
    cpuCount = 6;
    installDir = "/home/dayz/servers/Entropy";
    configFile = "serverDZ_Entropy.cfg";
    profileDir = "profiles";
    enableLogs = true;
    filePatching = false;
    autoUpdate = false;
    openFirewall = true;
    port = 2302;
    modDir = "mods";

    serverMods = [
      "@GameLabs"
      "@SpawnerBubaku"
      "@DayZ Editor Loader"
      "@Bitterroot_Gamelabs_Icons"
      "@Breachingcharge Codelock Compatibility"
      "@BreachingCharge RaidSchedule Compatibility"
      "@RaidSchedule - New and Improved"
    ];

    mods = [
      "@CF"
      "@Code Lock"
      "@MuchCarKey"
      "@CannabisPlus"
      "@BaseBuildingPlus"
      "@RaG_BaseItems"
      "@RUSForma_vehicles"
      "@FlipTransport"
      "@Forward Operator Gear"
      "@Breachingcharge"
      "@AdditionalMedicSupplies"
      "@Dogtags"
      "@GoreZ"
      "@Dabs Framework"
      "@DrugsPLUS"
      "@Car_Key_Slot"
      "@Survivor Animations"
      "@DayZ-Bicycle"
      "@MMG - Mightys Military Gear"
      "@RaG_Immersive_Wells"
      "@MBM_ChevySuburban1989"
      "@MBM_ImprezaWRX"
      "@CJ187-PokemonCards"
      "@Tactical Flava"
      "@SNAFU_Weapons"
      # "@MZ KOTH"
      "@RaG_Liquid_Framework"
      "@Alcohol Production"
      "@Wooden Chalk Sign (RELIFE)"
      "@Rip It Energy Drinks"
      "@SkyZ - Skybox Overhaul"
      "@TraderPlus"
      "@Ninjins-PvP-PvE"
      "@CookZ"
      "@Towing Service"
      "@Bitterroot"
      "@Entropy Server Pack"
    ];
  };

  # --- watchdog wiring that augments the generated unit ---
  systemd.services.dayz-server = {
    serviceConfig = {
      # Keep Type=simple so we don't need READY=1; watchdog works with simple units too
      NotifyAccess = "all";
      WatchdogSec = "15s";                # trip window (tune to taste)
      # When the unit stops, kill the whole cgroup (ensures notifier exits)
      KillMode = "control-group";

      # Launch the notifier in the same cgroup after the main ExecStart has begun
      ExecStartPost = lib.mkForce "${pkgs.bash}/bin/bash -lc '${dayzWatchdogNotify}/bin/dayz-watchdog-notify & disown'";

      # Optional: if graceful stop stalls, hard-kill after a grace period
      # ExecStopPost = lib.mkForce "${pkgs.bash}/bin/bash -lc 'sleep 90; systemctl kill -s SIGKILL dayz-server || true'";
    };

    # Env for the health script; adjust query port if yours is custom
    environment = {
      DAYZ_QUERY_HOST = "127.0.0.1";
      DAYZ_QUERY_PORT = "27016";          # set this to your actual Steam query port
      DAYZ_QUERY_TIMEOUT = "2.0";
      DAYZ_HEALTH_INTERVAL = "5";
      DAYZ_HEALTH_FAIL_MAX = "3";
      DAYZ_HEALTH_START_DELAY = "10";
    };
    # If you want periodic forced restarts (optional):
    # serviceConfig.RuntimeMaxSec = "12h";
  };

  # Optional firewall: not needed for localhost health; keep if you expose query port externally
  # networking.firewall.allowedUDPPorts = [ 27016 ];
}
