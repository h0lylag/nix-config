# Container configurations for beavercreek
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Enable container support
  boot.enableContainers = true;

  # Common container parameters
  # All containers use bridge networking with br0
  # All containers get their own MAC and DHCP lease
  # All containers are set to not autostart by default

  # Import individual container configurations
  imports = [
    ./test-container
    ./allianceauth
    ./zanzibar
  ];
}
