{ ... }:
{
  den.aspects.llm.nixos.imports = [
    ./llama-cpp.nix
    ./websearch.nix
  ];
}
