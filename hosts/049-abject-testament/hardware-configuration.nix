# Generic M75q hardware stub. Replace with nixos-generate-config output if this
# machine's hardware differs from the shared family definition.
{ ... }:

{
  imports = [ ../m75q-hardware-common.nix ];
}
