{ pkgs, ... }:

{
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "coagulation";
        "netbios name" = "coagulation";
        "security" = "user";
        "hosts allow" = "10.1.1. 127.0.0.1 ::1";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";

        # Windows Optimization
        "server multi channel support" = "yes";
      };

      "main" = {
        "path" = "/mnt/hdd-pool/main";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force user" = "chris";
        "force group" = "media";
        "vfs objects" = "acl_xattr";
      };
    };
  };
}
