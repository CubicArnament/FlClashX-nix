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
  core,
  src,
}:

let
  androidComposition = androidenv.composeAndroidPackages {
    platformVersions = [ "36" ];
    buildToolsVersions = [ "36.0.0" ];
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

    # nixpkgs injects this task through its Gradle init script. Unlike a
    # display-only `dependencies` invocation, it resolves every configuration
    # so mitm-cache can record the complete Maven graph.
    gradleUpdateTask = "nixDownloadDeps";
    # gradle.fetchDeps invokes its update task directly, before buildPhase.
    # Enter the Android Gradle project here so it resolves real configurations
    # rather than creating an empty build at the Flutter repository root.
    preGradleUpdate = "cd android";

    ANDROID_HOME = androidHome;
    ANDROID_SDK_ROOT = androidHome;
    ANDROID_NDK_ROOT = "${androidHome}/ndk/28.0.13004108";
    ANDROID_NDK = "${androidHome}/ndk/28.0.13004108";
    JAVA_HOME = jdk17;

    configurePhase = ''
      runHook preConfigure

      # Gradle's copyNativeLibs task deletes and recreates this directory.
      # The source tree is read-only in the dependency update sandbox, so make
      # the staged Go artifacts writable before Gradle configures the project.
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

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

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
