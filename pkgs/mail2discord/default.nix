{ lib, python3Packages }:

python3Packages.buildPythonApplication {
  pname = "mail2discord";
  version = "2.0";
  format = "other";

  src = ./.;

  propagatedBuildInputs = [ ];

  installPhase = ''
    install -Dm755 mail2discord.py $out/bin/mail2discord

    # Symlink as 'sendmail' so applications find it
    ln -s $out/bin/mail2discord $out/bin/sendmail
  '';

  meta = with lib; {
    description = "Sendmail shim to forward local mail to Discord";
    platforms = platforms.linux;
  };
}
