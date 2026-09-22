{
  lib,
  stdenv,
  fetchFromGitHub,
  buildDotnetModule,
  dotnetCorePackages,
}:

buildDotnetModule {
  pname = "jellyfin-xmltv";
  version = "10.12.0-pre1";

  # This is the source revision embedded in Jellyfin 12.1's XMLTV assembly.
  src = fetchFromGitHub {
    owner = "jellyfin";
    repo = "Jellyfin.XmlTv";
    rev = "6c8c302c8520e5f41cd51dd392ac631f97179d82";
    hash = "sha256-2vTuwYC16l28MrPmkbxIYG5j/Zlyiqdermu1BA3s5lo=";
  };

  patches = [ ./preserve-element-after-image.patch ];

  postPatch = ''
    cp -r ${./tests} regression
    chmod -R u+w regression
    cp ${./NuGet.Config} NuGet.Config
  '';

  projectFile = "src/Jellyfin.XmlTv/Jellyfin.XmlTv.csproj";
  testProjectFile = "regression/Regression.csproj";
  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  executables = [ ];

  # Release has no NuGet dependencies; Debug enables optional analyzers.
  dotnetRestoreFlags = [ "-p:Configuration=Release" ];
  # Preserve the identity of the unsigned assembly shipped with Jellyfin.
  dotnetFlags = [ "-p:AssemblyVersion=1.0.0.0" ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    dotnet regression/bin/Release/net10.0/${dotnetCorePackages.systemToDotnetRid stdenv.hostPlatform.system}/Regression.dll
    runHook postCheck
  '';

  meta = {
    description = "Jellyfin XMLTV parser with adjacent artwork element preservation";
    homepage = "https://github.com/jellyfin/Jellyfin.XmlTv";
    license = lib.licenses.mit;
    platforms = dotnetCorePackages.sdk_10_0.meta.platforms;
  };
}
