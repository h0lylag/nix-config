final: _prev:
let
  # Every top-level pkgs/<name>/package.nix is part of pkgs.local. Discover
  # ordinary recipes from that layout so adding one does not require a second
  # catalogue entry; keep only package-set and argument exceptions below.
  discovered = final.lib.filesystem.packagesFromDirectoryRecursive {
    inherit (final) callPackage;
    directory = ../pkgs;
  };
in
{
  local = discovered // {
    # Discovery stops at teamspeak3/package.nix, so expose its Qt stub here.
    teamspeak3 = final.callPackage ../pkgs/teamspeak3/package.nix {
      qtwebengine-stub = final.local.teamspeak3-qtwebengine-stub;
    };
    teamspeak3-qtwebengine-stub = final.callPackage ../pkgs/teamspeak3/qtwebengine-stub/package.nix { };

    # These two packages use libraries from the pinned unstable package set.
    imgcat-django = final.unstable.callPackage ../pkgs/imgcat-django/package.nix { };
    jellyfin-xmltv = final.unstable.callPackage ../pkgs/jellyfin-xmltv/package.nix { };
  };
}
