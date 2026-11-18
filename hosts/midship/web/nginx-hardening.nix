{ config, lib, ... }:

{
  # nginx2root: CVE-2026-123007 and CVE-2026-123633 need HTTP/2. This list must
  # name every TLS vhost; the assertion below catches omissions.
  services.nginx.virtualHosts =
    lib.genAttrs
      [
        "gravemind.sh"
        "epc.gravemind.sh"
        "ops.gravemind.sh"
        "prices.gravemind.sh"
        "prism.gravemind.sh"
        "prism-v1.gravemind.sh"
        "mc.gravemind.sh"
        "git.gravemind.sh"
        "willamettemachine.com"
        "lambdafleet.org"
        "evepreview.com"
        "manager.evepreview.com"
        "epm.sh"
        "img.cat"
        "jellyfin.gravemind.sh"
        "jellyseerr.gravemind.sh"
        "www.gravemind.sh"
        "www.willamettemachine.com"
        "www.lambdafleet.org"
        "www.evepreview.com"
        "www.epm.sh"
        "www.img.cat"
      ]
      (_: {
        http2 = false;
      });

  assertions = [
    {
      assertion = lib.all (v: !v.http2) (lib.attrValues config.services.nginx.virtualHosts);
      message = "midship nginx must keep HTTP/2 off until nginx 1.31.9 (see workarounds.nix: nginx2root).";
    }
  ];

  # The writeup chains the nginx bugs with a kernel SCTP bug for root.
  boot.extraModprobeConfig = "install sctp /bin/false";
}
