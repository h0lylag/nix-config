final: _prev: {
  teamspeak3 = final.callPackage ./package.nix {
    qtwebengine-stub = final.callPackage ./qtwebengine-stub/package.nix { };
  };
}
