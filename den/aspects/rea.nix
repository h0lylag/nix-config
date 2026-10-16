{ ... }:
{
  # REA's agent MCP registration and skill are installed imperatively with
  # `npx rea-agents@latest setup`; this only provides the runtime and providers.
  den.aspects.rea = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          nodejs_26
          ghidra
        ];
      };
  };
}
