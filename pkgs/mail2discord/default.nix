{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
}:

# Lightweight package for the mail2discord.py CLI.
#
# It installs two executables:
# - mail2discord: the main CLI (reads RFC-5322 mail from stdin)
# - mail2discord-sendmail: a shim suitable for use as a sendmail replacement
#   Both the main CLI and the shim will read the Discord webhook from sops-nix
#   at /run/secrets/mail2discord-webhook when DISCORD_WEBHOOK_URL is not set.

stdenvNoCC.mkDerivation rec {
  pname = "mail2discord";
  version = "1.1";

  src = ./.;

  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  installPhase = ''
    		runHook preInstall

    		# Install main script
    		install -Dm0755 ${./mail2discord.py} "$out/bin/mail2discord"
    		patchShebangs "$out/bin/mail2discord"

            # Wrapper that sources webhook from sops-nix secret if not provided
            cat > "$out/bin/mail2discord-sendmail" <<EOF
    		#!/usr/bin/env bash
    		set -euo pipefail
    		: "''${DISCORD_WEBHOOK_FILE:=/run/secrets/mail2discord-webhook}"
    		if [[ -z "''${DISCORD_WEBHOOK_URL:-}" ]] && [[ -f "$DISCORD_WEBHOOK_FILE" ]]; then
    			export DISCORD_WEBHOOK_URL="$(tr -d '\n\r' < "$DISCORD_WEBHOOK_FILE")"
    		fi
    		exec "$out/bin/mail2discord" "$@"
    		EOF
    		chmod +x "$out/bin/mail2discord-sendmail"

    		# Provide an explicit name to avoid shadowing a real system sendmail
    		ln -s "$out/bin/mail2discord-sendmail" "$out/bin/sendmail-mail2discord"

    		runHook postInstall
    	'';

  meta = with lib; {
    description = "Sendmail-style shim that posts emails to a Discord webhook";
    homepage = "https://github.com/h0lylag/nix-config";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
