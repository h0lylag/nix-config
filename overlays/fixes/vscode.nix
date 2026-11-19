final: prev: {
  # VS Code 1.144 moved its bundled ripgrep from @vscode/ripgrep/bin/rg to
  # @vscode/ripgrep-universal/bin/linux-x64/rg, so nixpkgs' postPatch fails on
  # the missing path. Point the same substitution at the new location.
  vscode = prev.vscode.overrideAttrs (old: {
    postPatch =
      builtins.replaceStrings
        [ "resources/app/node_modules/@vscode/ripgrep/bin/rg" ]
        [ "resources/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg" ]
        old.postPatch;
  });
}
