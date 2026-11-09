{ ... }:
{
  den.aspects.llm.nixos.imports = [
    ./llama-cpp.nix
    ./strata.nix
    ./websearch.nix
  ];
}
