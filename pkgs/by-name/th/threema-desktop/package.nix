{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeDesktopItem,
  copyDesktopItems,
  makeWrapper,
  electron,
  python3,
}:

let
  version = "1.2.46";
  electronSrc = fetchFromGitHub {
    owner = "threema-ch";
    repo = "threema-web-electron";
    rev = "refs/tags/${version}";
    hash = "sha256-Qv40l6TyYZL9WcRQeIYUgMFsJrr0XYC2nmtYBgQKXvY=";
  };

  threema-web = buildNpmPackage rec {
    pname = "threema-web";
    version = "2.5.7";

    src = fetchFromGitHub {
      owner = "threema-ch";
      repo = "threema-web";
      rev = "refs/tags/v${version}";
      hash = "sha256-WuPOOchFZtnLVoB+i4LKFkeSujYXpQN8RLrt9xG9/W0=";
    };

    npmDepsHash = "sha256-eJIVX2W0Fgk/OmkaN2cR+qFoHTOmu4RmluR3BEuPOAU=";
    npmBuildScript = "dist";

    nativeBuildInputs = [
      (python3.withPackages (ps: [ ps.setuptools ])) # Used by gyp
    ];

    patches = [
      "${electronSrc}/tools/patches/patch-user-agent.patch"
      "${electronSrc}/tools/patches/patch-looks.patch"
    ];

    postInstall = ''
      # Content of ${electronSrc}/tools/patches/post-patch-threema-web.sh
      export threema_web_version=threema-web-${version}
      sed -i.bak -E "s/IN_MEMORY_SESSION_PASSWORD:(true|false|0|1|\!0|\!1)/IN_MEMORY_SESSION_PASSWORD:true/g" -- release/$threema_web_version/*.bundle.js
      cp -r . "$out"
    '';
  };

  consumer = buildNpmPackage rec {
    pname = "threema-desktop-consumer";
    inherit version;
    src = electronSrc;
    sourceRoot = "${src.name}/app";
    npmDepsHash = "sha256-CRYcmly8S+waeCf2fRWM2o3IuBVdpk2gZ/djHhxLLTQ=";
    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    dontNpmBuild = true;
    prePatch = ''
      rm -r dependencies/threema-web
      cp -r ${threema-web} dependencies/threema-web
      chmod +w dependencies/threema-web
    '';
    postInstall = ''
      cp -r . "$out"
    '';
  };

in
buildNpmPackage rec {
  pname = "threema-desktop";
  inherit version;
  src = electronSrc;

  npmDepsHash = "sha256-OdxDAy9ybBUEFuQQtihEvUXCVtVtveksLlOBD8F1RP0=";

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  postPatch = ''
    rm -r app
    cp -r ${consumer} app
    chmod +w app
  '';

  npmBuildScript = "app:build:electron:main";

  # We need to install the consumer
  dontNpmInstall = true;

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "threema-desktop";
      exec = meta.mainProgram;
      icon = "threema";
      desktopName = "Threema Desktop";
      comment = meta.description;
    })
  ];

  postInstall = ''
    mkdir -p $out/opt
    cp -r app $out/opt/threema

    for dir in assets dependencies; do
      ln -s $out/opt/threema/$dir $out/opt/threema/dist/src/$dir
    done

    mkdir -p $out/share/pixmaps
    cp $out/opt/threema/assets/icons/svg/consumer.svg $out/share/pixmaps/threema.svg

    makeWrapper ${electron}/bin/electron $out/bin/threema \
      --add-flags $out/opt/threema/dist/src/main.js
  '';

  meta = with lib; {
    description = "Desktop client for Threema, a privacy-focused end-to-end encrypted mobile messenger";
    homepage = "https://threema.ch";
    license = licenses.agpl3Only;
    mainProgram = "threema";
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
  };
}
