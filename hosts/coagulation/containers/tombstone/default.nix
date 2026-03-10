{
  config,
  pkgs,
  lib,
  nixpkgs-unstable,
  ...
}:

{
  containers.tombstone = {
    autoStart = true;
    privateNetwork = true;
    hostBridge = "br0";

    config =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        imports = [ ../base.nix ];
        _module.args.nixpkgs-unstable = nixpkgs-unstable;

        networking.interfaces.eth0.ipv4.addresses = [
          {
            address = "10.1.1.8";
            prefixLength = 24;
          }
        ];

        services.adguardhome = {
          enable = true;
          host = "0.0.0.0";
          port = 3000;
          openFirewall = true;
          mutableSettings = true;

          settings = {
            dns = {
              upstream_dns = [
                "9.9.9.9#dns.quad9.net"
                "149.112.112.112#dns.quad9.net"
              ];
            };
            filtering = {
              protection_enabled = true;
              filtering_enabled = true;
              parental_enabled = false;
              safe_search.enabled = false;
            };
            filters =
              map
                (url: {
                  enabled = true;
                  url = url;
                })
                [
                  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
                  "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt"
                ];
          };
        };
      };
  };
}
