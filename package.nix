{
  lib,
  flutter341,
  gtk3,
  libayatana-appindicator,
  keybinder3,
  gsettings-desktop-schemas,
  glib,
  makeWrapper,
  core,
  src,
  xdg-utils,
}:

flutter341.buildFlutterApplication {
  pname = "flclashx";
  version = "0.4.2";

  inherit src;
  pubspecLock = lib.importJSON ./pubspec-lock.json;
  gitHashes.flutter_js = "sha256-4PgiUL7aBnWVOmz2bcSxKt81BRVMnopabj5LDbtPYk4=";

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    gtk3
    libayatana-appindicator
    keybinder3
    gsettings-desktop-schemas
  ];

  preBuild = ''
    mkdir -p libclash/linux
    cp ${core}/bin/FlClashCore libclash/linux/FlClashCore
    chmod +x libclash/linux/FlClashCore
  '';

  flutterBuildFlags = [
    "--dart-define=APP_ENV=stable"
    "--dart-define=CORE_VERSION=v1.19.28"
    "--dart-define=APP_VERSION=0.4.2"
  ];

  postInstall = ''
    install -Dm644 assets/images/icon.png \
      $out/share/icons/hicolor/256x256/apps/flclashx.png
    install -Dm644 linux/com.follow.clashx.desktop \
      $out/share/applications/com.follow.clashx.desktop

    wrapProgram $out/bin/FlClashX \
      --prefix PATH : ${
        lib.makeBinPath [
          core
          glib
          xdg-utils
        ]
      }
  '';

  meta = {
    description = "Flutter proxy client based on Mihomo";
    homepage = "https://github.com/pluralplay/FlClashX";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "FlClashX";
  };
}
