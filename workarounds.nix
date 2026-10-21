# Temporary workarounds that should go away once upstream catches up.
# scripts/check-workarounds.sh (run by scripts/check-config.sh) reports their
# status against the locked inputs, so a status changes after an input update.
#
# `ready` is true when the removal condition looks met, false while it is not,
# and null when only a manual check can tell. A version-change probe means the
# workaround is worth retrying, not that upstream has confirmed a fix.
{ inputs, lib, ... }:
let
  stable = inputs.nixpkgs.legacyPackages.x86_64-linux;
  unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
in
{
  flake.workarounds = {
    php-security-pin = {
      files = [
        "overlays/replacements/php.nix"
        "hosts/midship/default.nix"
        "flake.nix"
      ];
      why = "PHP 8.4.27 fixes PHP2Shell (CVE-2026-109618, CVE-2026-109619) on midship.";
      removeWhen = "nixpkgs ships PHP 8.4.27 or later; also drop the nixpkgs-php input.";
      ready = lib.versionAtLeast stable.php.version "8.4.27";
    };

    v4l2loopback-depmod = {
      files = [
        "overlays/fixes/v4l2loopback.nix"
        "hosts/relic/default.nix"
      ];
      why = "Kernel 7.2's depmod index files collide with the kernel's own; backports NixOS/nixpkgs#575861.";
      removeWhen = "nixpkgs-unstable includes NixOS/nixpkgs#575861.";
      ready = builtins.elem "DEPMOD=true" (
        unstable.linuxPackages_latest.v4l2loopback.installFlags or [ ]
      );
    };

    open-webui-disabled = {
      files = [ "hosts/relic/default.nix" ];
      why = "open-webui 0.12.3 fails to build on nixpkgs-unstable's Python 3.14.";
      removeWhen = "open-webui builds again (flagged once it moves past 0.12.3); re-enable it on relic.";
      ready = unstable.open-webui.version != "0.12.3";
    };

    hexstrike-angr = {
      files = [ "den/aspects/hexstrike.nix" ];
      why = "angr's recipe fails to build at the nixpkgs-unstable pin (missing setuptools-rust).";
      removeWhen = "angr builds again (flagged once it moves past 9.2.193); add it back to the env.";
      ready = unstable.python313Packages.angr.version != "9.2.193";
    };

    hexstrike-python313 = {
      files = [ "den/aspects/hexstrike.nix" ];
      why = "nixpkgs-unstable's default Python 3.14 package set was not fully cached.";
      removeWhen = "Python 3.14 packages are cached; switch the env back to python3.";
      ready = null;
    };

    prism-django-uvicorn = {
      files = [ "pkgs/prism-django/package.nix" ];
      why = "Uvicorn 0.51 adds the max-request jitter used by prism's request recycling.";
      removeWhen = "nixpkgs ships uvicorn 0.51 or later.";
      ready = lib.versionAtLeast stable.python313Packages.uvicorn.version "0.51";
    };

    prism-django-pydantic = {
      files = [ "pkgs/prism-django/package.nix" ];
      why = "django-esi 9.6 needs a newer Pydantic stack than nixpkgs provides.";
      removeWhen = "nixpkgs ships pydantic 2.14 and pydantic-core 2.47 or later.";
      ready =
        lib.versionAtLeast stable.python313Packages.pydantic.version "2.14"
        && lib.versionAtLeast stable.python313Packages.pydantic-core.version "2.47";
    };

    uplift-qui-tests = {
      files = [ "hosts/coagulation/containers/uplift/default.nix" ];
      why = "qui's upstream tests fail, so uplift builds it locally with checks disabled.";
      removeWhen = "qui's tests pass (flagged once it moves past 1.32.0).";
      ready = unstable.qui.version != "1.32.0";
    };

    amethyst-xxhash = {
      files = [ "den/aspects/gaming.nix" ];
      why = "The Amethyst Mod Manager package omits xxhash, which Wabbajack list imports need.";
      removeWhen = "The amethyst-mod-manager flake ships xxhash.";
      ready = null;
    };

    den-strict-schema = {
      files = [ "den/schema.nix" ];
      why = "Den's blanket strict module rejects valid nixos aspect content at the pinned revision.";
      removeWhen = "A newer Den accepts it (flagged once the den pin changes); apply den.lib.strict to the whole schema.";
      ready = inputs.den.rev != "d50f0fce6fc1a8ba00fd0d310746d0e8ecc2f70d";
    };
  };
}
