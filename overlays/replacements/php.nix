{ inputs }:
_final: prev: {
  # PHP 8.4.27 fixes CVE-2026-109618 and CVE-2026-109619 (php2shell). The pin is
  # the NixOS/nixpkgs#576865 merge on release-26.05; remove this overlay and the
  # nixpkgs-php input once the nixos-26.05 channel includes it.
  php = inputs.nixpkgs-php.legacyPackages.${prev.stdenv.hostPlatform.system}.php;
}
