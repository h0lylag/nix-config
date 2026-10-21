{ ... }:
{
  # HexStrike AI (https://github.com/0x4m4/hexstrike-ai) is a Flask server that
  # orchestrates external security tools, plus a thin MCP client bridge. The two
  # scripts carry no release to pin, so clone them imperatively:
  #   git clone https://github.com/0x4m4/hexstrike-ai ~/tools/hexstrike-ai
  # (override the location with HEXSTRIKE_DIR). This aspect supplies the Python
  # interpreter so no pip/venv is needed on NixOS, the external tools the server
  # shells out to, and `hexstrike-server` / `hexstrike-mcp` launchers that run
  # the clone with that interpreter.
  den.aspects.hexstrike.nixos =
    { pkgs, ... }:
    let
      # Pure-Nix env for both scripts: the server's native deps (angr, pwntools,
      # mitmproxy) ship prebuilt wheels that will not run under pip on NixOS, but
      # all of them are packaged here. mcp provides mcp.server.fastmcp.FastMCP
      # for the client bridge (the standalone fastmcp 3.x is a different package).
      pythonEnv = pkgs.python3.withPackages (
        ps: with ps; [
          flask
          requests
          psutil
          beautifulsoup4
          selenium
          webdriver-manager
          aiohttp
          mitmproxy
          pwntools
          angr
          bcrypt
          mcp
        ]
      );

      # Selenium 4 otherwise fetches a chromedriver ELF that will not run on
      # NixOS; pin it and the browser to matching Nix-built binaries.
      hexstrike-server = pkgs.writeShellScriptBin "hexstrike-server" ''
        export CHROMEDRIVER="${pkgs.chromedriver}/bin/chromedriver"
        export CHROME_BIN="${pkgs.chromium}/bin/chromium"
        exec ${pythonEnv}/bin/python3 "''${HEXSTRIKE_DIR:-$HOME/tools/hexstrike-ai}/hexstrike_server.py" "$@"
      '';

      hexstrike-mcp = pkgs.writeShellScriptBin "hexstrike-mcp" ''
        exec ${pythonEnv}/bin/python3 "''${HEXSTRIKE_DIR:-$HOME/tools/hexstrike-ai}/hexstrike_mcp.py" "$@"
      '';
    in
    {
      environment.systemPackages = [
        hexstrike-server
        hexstrike-mcp
      ]
      ++ (with pkgs; [
        # recon / network
        nmap
        masscan
        rustscan
        amass
        subfinder
        nuclei
        # web application
        gobuster
        feroxbuster
        ffuf
        dirb
        nikto
        sqlmap
        wpscan
        httpx
        katana
        wafw00f
        dalfox
        # auth / passwords
        hydra
        john
        hashcat
        medusa
        netexec
        # binary analysis / forensics (ghidra is shared with den.aspects.rea on relic)
        radare2
        binwalk
        ghidra
        gdb
        volatility3
        exiftool
        steghide
        # cloud / containers
        trivy
        # browser agent driver (chromium itself comes from the workstation aspect)
        chromedriver
      ]);
    };
}
