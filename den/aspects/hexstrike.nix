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
      # Pure-Nix env for both scripts: the server's native deps ship prebuilt
      # wheels that will not run under pip on NixOS, but they are packaged here.
      # mcp provides mcp.server.fastmcp.FastMCP for the client bridge (the
      # standalone fastmcp 3.x is a different package). Pinned to python313
      # because unstable's default python3 is 3.14, whose package set is not yet
      # fully built in the cache. angr is intentionally omitted: its recipe is
      # broken at this nixpkgs pin (missing setuptools-rust) and the server only
      # imports it lazily for one binary-analysis tool, so its absence does not
      # affect startup or the other tools. Add `angr` back once it builds.
      pythonEnv = pkgs.python313.withPackages (
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
      # Every tool from hexstrike's detection list (hexstrike_server.py) that
      # builds on this nixpkgs pin. The aspect stays self-contained: entries
      # another aspect also installs (e.g. ghidra, file) are identical
      # derivations and deduplicate in the system path.
      #   Not packaged in nixpkgs: autorecon, paramspider, x8, spiderfoot,
      #   social-analyzer, dotdotpwn, docker-bench-security, falco (anew and
      #   patator are removed upstream).
      #   Packaged but broken at this pin, so omitted: bulk_extractor (-Werror),
      #   checkov and prowler (their detect-secrets dep fails its tests on
      #   python 3.14). Add them back once nixpkgs fixes the builds.
      ++ (with pkgs; [
        # recon / network
        nmap
        masscan
        rustscan
        nbtscan
        arp-scan
        responder
        netexec # provides `nxc`
        enum4linux
        enum4linux-ng
        samba # rpcclient / smbclient
        amass
        subfinder
        fierce
        dnsenum
        dnsrecon
        smbmap
        onesixtyone
        snmpcheck
        assetfinder
        dnsx
        naabu
        # web application
        gobuster
        feroxbuster
        ffuf
        dirb
        dirsearch
        nikto
        sqlmap
        nuclei
        wpscan
        arjun
        katana
        httpx
        dalfox
        jaeles
        hakrawler
        gau
        waybackurls
        wafw00f
        whatweb
        wfuzz
        gowitness
        cewl
        xsser
        burpsuite
        # auth / passwords (thc-hydra provides the `hydra` binary; plain `hydra`
        # is the unrelated Nix CI server)
        thc-hydra
        john
        hashcat
        hashcat-utils
        medusa
        ncrack
        evil-winrm
        hash-identifier
        hashid
        ophcrack
        # binary analysis / reverse engineering
        gdb
        radare2
        binwalk
        ropgadget
        python3Packages.ropper
        checksec
        binutils # strings / objdump
        ghidra
        one_gadget
        pwninit
        # forensics / stego
        volatility3
        foremost
        scalpel
        sleuthkit
        autopsy
        testdisk # also provides photorec
        steghide
        stegsolve
        zsteg
        outguess
        hashpump
        exiftool
        file
        xxd
        # cloud / containers
        trivy
        scoutsuite
        kube-hunter
        kube-bench
        terrascan
        clair
        # osint (shodan/censys ship their CLIs as python packages)
        sherlock
        recon-ng
        theharvester
        maltego
        python3Packages.shodan
        python3Packages.censys
        # exploitation framework (large ruby closure)
        metasploit
        exploitdb # searchsploit
        # api / web clients
        curl
        httpie
        qsreplace
        uro
        postman
        insomnia
        # sniffing / wireless (wireshark provides tshark)
        wireshark
        tcpdump
        kismet
        aircrack-ng
        # wordlists
        seclists
        wordlists
        # browser agent driver (chromium is pulled in by the launcher's store
        # path, not systemPackages, to avoid clashing with the workstation
        # aspect's chromium override)
        chromedriver
      ]);
    };
}
