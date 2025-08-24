{
  config,
  lib,
  pkgs,
  ...
}:

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

  # 2) Notifier with warm-up: arms watchdog only after startup is actually healthy
  dayzWatchdogNotify = pkgs.writeShellScriptBin "dayz-watchdog-notify" ''
    #!/usr/bin/env bash
    # no -u: we intentionally reference unset vars like $WATCHDOG_USEC
    set -eo pipefail

    HEALTH="${a2sHealthcheck}/bin/a2s_healthcheck.py"

    # Tunables via unit Environment=
    WARMUP_SECS="$DAYZ_HEALTH_WARMUP_SECS";           [ -z "$WARMUP_SECS" ] && WARMUP_SECS=120
    MIN_OK_BEFORE_READY="$DAYZ_HEALTH_OK_BEFORE_READY"; [ -z "$MIN_OK_BEFORE_READY" ] && MIN_OK_BEFORE_READY=2
    INTERVAL="$DAYZ_HEALTH_INTERVAL";                 [ -z "$INTERVAL" ] && INTERVAL=5
    FAIL_MAX="$DAYZ_HEALTH_FAIL_MAX";                 [ -z "$FAIL_MAX" ] && FAIL_MAX=3

    start_ts=$(date +%s)
    ok_streak=0

    # --------- WARMUP PHASE ---------
    # Don't arm the watchdog until either we see consecutive healthy A2S replies,
    # or a hard warmup timeout elapses.
    while : ; do
      now=$(date +%s)
      elapsed=$(( now - start_ts ))

      if "$HEALTH" ; then
        ok_streak=$((ok_streak + 1))
        if [ "$ok_streak" -ge "$MIN_OK_BEFORE_READY" ]; then
          break
        fi
      else
        ok_streak=0
      fi

      if [ "$elapsed" -ge "$WARMUP_SECS" ]; then
        echo "dayz-watchdog: warmup timeout ($WARMUP_SECS s) reached; arming watchdog anyway"
        break
      fi

      sleep "$INTERVAL"
    done

    # Announce READY — this arms the systemd watchdog for Type=notify units
    ${pkgs.systemd}/bin/systemd-notify --ready || true

    # If systemd exported a watchdog window, use half as our ping cadence
    if [ -n "$WATCHDOG_USEC" ]; then
      wd_interval=$(( WATCHDOG_USEC / 2 / 1000000 ))
      [ "$wd_interval" -lt 1 ] && wd_interval=1
      INTERVAL="$wd_interval"
    fi

    # --------- STEADY-STATE PING LOOP ---------
    fails=0
    while : ; do
      if "$HEALTH" ; then
        fails=0
        ${pkgs.systemd}/bin/systemd-notify --watchdog || true
      else
        fails=$((fails + 1))
        if [ "$fails" -ge "$FAIL_MAX" ]; then
          echo "dayz-watchdog: health failed $fails times; stopping notifications (systemd watchdog will trip)"
          # do nothing else; without --watchdog pings, systemd will expire the unit
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
      Type = "notify"; # arm watchdog only after READY
      NotifyAccess = "all";
      WatchdogSec = "60s"; # give headroom for heavy mod loads; tighten later
      KillMode = "control-group";

      # Launch the notifier in the same cgroup after ExecStart begins
      ExecStartPost = lib.mkForce "${pkgs.bash}/bin/bash -lc '${dayzWatchdogNotify}/bin/dayz-watchdog-notify & disown'";

      # Optional: if graceful stop stalls, hard-kill after a grace period
      # ExecStopPost = lib.mkForce "${pkgs.bash}/bin/bash -lc 'sleep 90; systemctl kill -s SIGKILL dayz-server || true'";
    };

    # Env for the health scripts; adjust query port if yours is custom
    environment = {
      DAYZ_QUERY_HOST = "127.0.0.1";
      DAYZ_QUERY_PORT = "27016"; # set this to your actual Steam query port
      DAYZ_QUERY_TIMEOUT = "2.0";

      # Health cadence and thresholds
      DAYZ_HEALTH_INTERVAL = "5";
      DAYZ_HEALTH_FAIL_MAX = "3";

      # Warm-up policy (new)
      DAYZ_HEALTH_WARMUP_SECS = "150"; # try 120–180s for your mod stack
      DAYZ_HEALTH_OK_BEFORE_READY = "2"; # require 2 consecutive A2S OKs before READY
    };

    # If you want periodic forced restarts (optional):
    # serviceConfig.RuntimeMaxSec = "12h";
  };

  # Optional firewall: not needed for localhost health; keep if you expose query port externally
  # networking.firewall.allowedUDPPorts = [ 27016 ];
}
