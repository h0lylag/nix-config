{
  config,
  lib,
  pkgs,
  ...
}:

{
  # DayZ Server Configuration
  services.dayz-server = {
    enable = true;
    user = "dayz";
    group = "users";
    steamLogin = "the_h0ly_christ";
    cpuCount = 6;
    installDir = "/home/dayz/servers/Entropy";
    configFile = "serverDZ_Entropy.cfg";
    profileDir = "profiles";
    enableLogs = true;
    filePatching = false;
    autoUpdate = false;
    openFirewall = true;

    # Server port configuration
    port = 2302;

    # Mod directory configuration
    modDir = "mods";

    # Server-only mods (not downloaded by clients)
    serverMods = [
      "@GameLabs"
      "@SpawnerBubaku"
      "@DayZ Editor Loader"
      "@Bitterroot_Gamelabs_Icons"
      "@Breachingcharge Codelock Compatibility"
      "@BreachingCharge RaidSchedule Compatibility"
      "@RaidSchedule - New and Improved"
    ];

    # Client mods (downloaded by clients)
    mods = [
      "@CF"
      "@Code Lock"
      "@MuchCarKey"
      "@CannabisPlus"
      "@BaseBuildingPlus"
      "@RaG_BaseItems"
      "@RUSForma_vehicles"
      "@FlipTransport"
      "@Forward Operator Gear"
      "@Breachingcharge"
      "@AdditionalMedicSupplies"
      "@Dogtags"
      "@GoreZ"
      "@Dabs Framework"
      "@DrugsPLUS"
      "@Car_Key_Slot"
      "@Survivor Animations"
      "@DayZ-Bicycle"
      "@MMG - Mightys Military Gear"
      "@RaG_Immersive_Wells"
      "@MBM_ChevySuburban1989"
      "@MBM_ImprezaWRX"
      "@CJ187-PokemonCards"
      "@Tactical Flava"
      "@SNAFU_Weapons"
      "@MZ KOTH"
      "@RaG_Liquid_Framework"
      "@Alcohol Production"
      "@Wooden Chalk Sign (RELIFE)"
      "@Rip It Energy Drinks"
      "@SkyZ - Skybox Overhaul"
      "@TraderPlus"
      "@Ninjins-PvP-PvE"
      "@CookZ"
      "@Towing Service"
      "@Bitterroot"
      "@Entropy Server Pack"
    ];
  };
}
