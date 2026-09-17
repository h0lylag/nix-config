# Stub Disko wrapper. Override disk.main.device with this machine's stable
# /dev/disk/by-id path after inventory.
{ ... }:

{
  imports = [ ../m75q-disko-common.nix ];
}
