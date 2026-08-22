# Netdata Parent for host and systemd-nspawn resource metrics
{
  lib,
  pkgs,
  ...
}:

{
  # The maintained Netdata Cloud UI is unfree. The base profile already
  # permits unfree packages, but keep the package-level exception explicit
  # for this service's dependency graph.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "netdata" ];

  services.netdata = {
    enable = true;
    package = pkgs.netdata.override {
      withCloudUi = true;
    };

    # Keep host history on the local dbengine. These are intentionally
    # conservative starting values; tune them after measuring metric volume.
    config = {
      global = {
        hostname = "coagulation";
        "debug log" = "syslog";
        "access log" = "none";
        "error log" = "syslog";
      };

      db = {
        db = "dbengine";
        "storage tiers" = 3;
        "dbengine tier 0 retention time" = "7d";
        "dbengine tier 0 retention size" = "4GiB";
        "dbengine tier 1 retention time" = "30d";
        "dbengine tier 1 retention size" = "2GiB";
        "dbengine tier 2 retention time" = "1y";
        "dbengine tier 2 retention size" = "2GiB";
      };

      web = {
        # Firewall policy limits this listener to the LAN and tailscale0;
        # access lists provide a second layer for dashboard and child streams.
        "bind to" = "*:19999";
        "allow connections from" = "localhost 100.* 10.1.1.*";
        "allow dashboard from" = "localhost 100.* 10.1.1.*";
        "allow badges from" = "localhost 100.* 10.1.1.*";
        "allow streaming from" = "100.*";
        "allow netdata.conf" = "localhost";
        "allow management from" = "localhost";
      };
    };
  };

  # Tailscale is already trusted by the shared host profile. Expose the
  # dashboard on both the private LAN bridge and tailscale0.
  networking.firewall.interfaces = {
    br0.allowedTCPPorts = [ 19999 ];
    tailscale0.allowedTCPPorts = [ 19999 ];
  };
}
