{ ... }:
{
  den.aspects.llm.nixos =
    { lib, pkgs, ... }:
    let
      searxPort = 25264;
      mcpSearxngPort = 20830;
      searxSecretFile = "/var/lib/searx-secret/env";
    in
    {
      services = {
        llama-cpp = {
          enable = true;

          settings = {
            # Reachable only over the tailnet: the firewall trusts tailscale0
            # and keeps the LAN closed.
            host = "::";

            # Stock Qwen3.6, kept for comparison:
            # hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL";
            # alias = "qwen3.6-35b-a3b";

            # Hugging Face rejects the custom Q4_K_P quant as a -hf tag, so the
            # file is named directly.
            hf-repo = "HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive";
            hf-file = "Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf";
            alias = "qwen3.6-35b-a3b-uncensored";
            no-mmproj = true;

            # Only 10 of 40 layers keep a KV cache, so the full context is about
            # 5.4 GiB at f16. Without GPU layer flags, --fit keeps attention and
            # KV in VRAM and moves the MoE experts to RAM.
            ctx-size = 262144;
            flash-attn = "on";
            parallel = 1;

            # Qwen's thinking-mode sampling for coding.
            temp = 0.6;
            top-p = 0.95;
            top-k = 20;
            min-p = 0.0;

            # Free VRAM for games after an idle hour.
            sleep-idle-seconds = 3600;

            # llama-server only spawns stdio MCP servers, and this unit's
            # MemoryDenyWriteExecute breaks Node, so mcp-searxng runs as its own
            # service behind mcp-proxy.
            mcp-servers-config = (pkgs.formats.json { }).generate "llama-cpp-mcp.json" {
              mcpServers.searxng = {
                command = lib.getExe pkgs.mcp-proxy;
                args = [
                  "--log-level"
                  "WARNING"
                  "--transport"
                  "streamablehttp"
                  "http://127.0.0.1:${toString mcpSearxngPort}/mcp"
                ];
              };
            };
          };
        };

        searx = {
          enable = true;
          environmentFile = searxSecretFile;
          settings = {
            server = {
              bind_address = "127.0.0.1";
              port = searxPort;
              secret_key = "$SEARX_SECRET_KEY";
              limiter = false;
              public_instance = false;
              image_proxy = false;
            };
            search.formats = [
              "html"
              "json"
            ];
            # The default engines CAPTCHA or rate-limit this IP; Bing works but
            # ships disabled.
            engines = [
              {
                name = "bing";
                disabled = false;
              }
            ];
          };
        };
      };

      systemd.services = {
        # The first start downloads the model, and MCP tools are only listed at
        # startup.
        llama-cpp = {
          wants = [
            "network-online.target"
            "mcp-searxng.service"
          ];
          after = [
            "network-online.target"
            "mcp-searxng.service"
          ];
        };

        # The key only signs limiter and image proxy tokens, both disabled, so
        # it does not need to be a managed secret.
        searx-secret = {
          description = "Generate the SearXNG secret key";
          requiredBy = [ "searx-init.service" ];
          before = [ "searx-init.service" ];
          unitConfig.ConditionPathExists = "!${searxSecretFile}";
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "searx-secret";
            StateDirectoryMode = "0700";
            UMask = "0077";
          };
          script = ''
            echo "SEARX_SECRET_KEY=$(${lib.getExe pkgs.openssl} rand -hex 32)" > ${searxSecretFile}
          '';
        };

        mcp-searxng = {
          description = "SearXNG MCP server";
          wantedBy = [ "multi-user.target" ];
          wants = [ "searx.service" ];
          after = [ "searx.service" ];
          environment = {
            SEARXNG_URL = "http://127.0.0.1:${toString searxPort}";
            MCP_HTTP_HOST = "127.0.0.1";
            MCP_HTTP_PORT = toString mcpSearxngPort;
            # Page reads paginate; small chunks keep prompt processing quick.
            URL_READ_MAX_CHARS = "20000";
          };
          serviceConfig = {
            ExecStart = lib.getExe pkgs.mcp-searxng;
            # Only report started once the endpoint answers.
            ExecStartPost = "${lib.getExe pkgs.curl} -sf -o /dev/null --retry 30 --retry-connrefused --retry-delay 1 http://127.0.0.1:${toString mcpSearxngPort}/health";
            Restart = "on-failure";

            DynamicUser = true;
            CapabilityBoundingSet = [ "" ];
            LockPersonality = true;
            # MemoryDenyWriteExecute is left off because V8's JIT needs it off.
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            PrivateUsers = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            ProtectSystem = "strict";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
            ];
          };
        };
      };
    };
}
