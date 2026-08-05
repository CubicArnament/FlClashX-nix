{
  lib,
  stdenvNoCC,
  androidenv,
  flutter341,
  go_1_26,
  jdk17,
  gradle_8,
  git,
  cacert,
  jq,
  core,
  flclashx,
  src,
}:

let
  androidComposition = androidenv.composeAndroidPackages {
    platformVersions = [ "36" ];
    buildToolsVersions = [
      "35.0.0"
      "36.0.0"
    ];
    abiVersions = [
      "armeabi-v7a"
      "arm64-v8a"
      "x86_64"
    ];
    includeNDK = true;
    ndkVersions = [ "28.0.13004108" ];
    includeCmake = true;
    cmakeVersions = [ "3.22.1" ];
    includeEmulator = false;
    includeSystemImages = false;
  };
  androidSdk = androidComposition.androidsdk;
  androidHome = "${androidSdk}/libexec/android-sdk";
  androidNdk = "${androidHome}/ndk/28.0.13004108";

  androidCore = core.overrideAttrs (previousAttrs: {
    pname = "flclashx-android-core";
    nativeBuildInputs = (previousAttrs.nativeBuildInputs or [ ]) ++ [ androidSdk ];

    buildPhase = ''
      runHook preBuild

      ndkBin=${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin
      mkdir -p artifacts/android/includes

      buildAndroidCore() {
        abi=$1
        goarch=$2
        cc=$3
        mkdir -p "artifacts/android/$abi" "artifacts/android/includes/$abi"
        env \
          GOOS=android \
          GOARCH="$goarch" \
          CGO_ENABLED=1 \
          CC="$ndkBin/$cc" \
          CFLAGS="-O3 -Werror" \
          go build \
            -trimpath \
            -buildmode=c-shared \
            -tags=with_gvisor,cmfa \
            -ldflags="-buildid= -w -s -X github.com/metacubex/mihomo/constant.Version=v1.19.28" \
            -o "artifacts/android/$abi/libclash.so" .
        mv "artifacts/android/$abi/libclash.h" \
          "artifacts/android/includes/$abi/libclash.h"
      }

      buildAndroidCore armeabi-v7a arm armv7a-linux-androideabi21-clang
      buildAndroidCore arm64-v8a arm64 aarch64-linux-android21-clang
      buildAndroidCore x86_64 amd64 x86_64-linux-android21-clang

      runHook postBuild
    '';

    postBuild = "";
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r artifacts/android $out/android
      runHook postInstall
    '';
  });

  androidBase = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "flclashx-android";
    version = "0.4.2";

    inherit src;

    nativeBuildInputs = [
      flutter341
      go_1_26
      jdk17
      gradle_8
      androidSdk
      git
      cacert
    ];

    mitmCache = gradle_8.fetchDeps {
      pkg = finalAttrs.finalPackage;
      data = ./gradle-deps.json;
    };

    gradleUpdateScript = ''
      runHook preBuild
      export GRADLE_OPTS="''${GRADLE_OPTS:-} \
        -Dhttp.proxyHost=$MITM_CACHE_HOST \
        -Dhttp.proxyPort=$MITM_CACHE_PORT \
        -Dhttps.proxyHost=$MITM_CACHE_HOST \
        -Dhttps.proxyPort=$MITM_CACHE_PORT \
        -Djavax.net.ssl.trustStore=$MITM_CACHE_KEYSTORE \
        -Djavax.net.ssl.trustStorePassword=$MITM_CACHE_KS_PWD"
      flutter build apk \
        --release \
        --no-pub \
        --dart-define=APP_ENV=stable \
        --dart-define=CORE_VERSION=v1.19.28 \
        --dart-define=APP_VERSION=0.4.2
      runHook postBuild
    '';

    ANDROID_HOME = androidHome;
    ANDROID_SDK_ROOT = androidHome;
    ANDROID_NDK_ROOT = "${androidHome}/ndk/28.0.13004108";
    ANDROID_NDK = "${androidHome}/ndk/28.0.13004108";
    JAVA_HOME = jdk17;

    configurePhase = ''
      runHook preConfigure

      export HOME=$TMPDIR/home
      mkdir -p $HOME
      cat > android/local.properties <<EOF
      flutter.sdk=${flutter341}
      sdk.dir=$ANDROID_HOME
      ndk.dir=$ANDROID_NDK_ROOT
      EOF

      mkdir -p libclash
      cp -r ${androidCore}/android libclash/android
      chmod -R u+w libclash/android

      mkdir -p .dart_tool
      cp ${flclashx.pubcache}/package_config.json .dart_tool/package_config.json
      ${jq}/bin/jq -n --slurpfile lock ${./pubspec-lock.json} '
        {
          configVersion: 1,
          roots: ["flclashx"],
          packages: (
            [
              {
                name: "flclashx",
                version: "0.4.2",
                dependencies: [
                  $lock[0].packages
                  | to_entries[]
                  | select(.value.dependency | startswith("direct"))
                  | .key
                ],
                devDependencies: [],
                dependencyOverrides: []
              }
            ]
            + [
              $lock[0].packages
              | to_entries[]
              | {
                  name: .key,
                  version: .value.version,
                  dependencies: [],
                  devDependencies: [],
                  dependencyOverrides: []
                }
            ]
          )
        }
      ' > .dart_tool/package_graph.json

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      export GRADLE_OPTS="''${GRADLE_OPTS:-} \
        -Dhttp.proxyHost=$MITM_CACHE_HOST \
        -Dhttp.proxyPort=$MITM_CACHE_PORT \
        -Dhttps.proxyHost=$MITM_CACHE_HOST \
        -Dhttps.proxyPort=$MITM_CACHE_PORT \
        -Djavax.net.ssl.trustStore=$MITM_CACHE_KEYSTORE \
        -Djavax.net.ssl.trustStorePassword=$MITM_CACHE_KS_PWD"
      flutter build apk \
        --release \
        --no-pub \
        --dart-define=APP_ENV=stable \
        --dart-define=CORE_VERSION=v1.19.28 \
        --dart-define=APP_VERSION=0.4.2

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      install -Dm644 build/app/outputs/flutter-apk/app-release.apk \
        $out/FlClashX-android-universal.apk
      runHook postInstall
    '';

    passthru = {
      inherit androidSdk androidComposition;
    };

    meta = {
      description = "Reproducible Android APK for FlClashX";
      homepage = "https://github.com/pluralplay/FlClashX";
      license = lib.licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
    };
  });
in
androidBase
