{ ... }:
{
  den.aspects.llm.nixos.imports = [
    ./llama-cpp.nix
    ./maya.nix
    ./strata.nix
    ./websearch.nix
  ];
}
