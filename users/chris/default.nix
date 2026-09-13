{ den, ... }:
{
  den.aspects.chris = {
    # Receive user-class settings from the features selected by this host.
    includes = [ den.batteries.host-aspects ];

    # The user class configures the OS account.
    user = { ... }: {
      isNormalUser = true;
      initialPassword = "chris";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWU3a+HOcu4woQiuMoCSxrW8g916Z9P05DW8o7cGysH chris@relic"
      ];
    };

    homeManager.imports = [ ./home.nix ];
  };
}
