final: _prev: {
  local = {
    command-code = final.callPackage ../pkgs/command-code/package.nix { };
    dayz-tools = final.callPackage ../pkgs/dayz-tools/package.nix { };
    eve-online = final.callPackage ../pkgs/eve-online/package.nix { };
    evemon = final.callPackage ../pkgs/evemon/package.nix { };
    insta360-studio = final.callPackage ../pkgs/insta360-studio/package.nix { };
    jeveassets = final.callPackage ../pkgs/jeveassets/package.nix { };
    rift = final.callPackage ../pkgs/rift/package.nix { };
    rusty-shovel = final.callPackage ../pkgs/rusty-shovel/package.nix { };
    teamspeak3 = final.callPackage ../pkgs/teamspeak3/package.nix {
      qtwebengine-stub = final.callPackage ../pkgs/teamspeak3/qtwebengine-stub/package.nix { };
    };

    # These two packages use libraries from the pinned unstable package set.
    imgcat-django = final.unstable.callPackage ../pkgs/imgcat-django/package.nix { };
    jellyfin-xmltv = final.unstable.callPackage ../pkgs/jellyfin-xmltv/package.nix { };
  };
}
