{
  description = "FlClashX for NixOS and Android";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/104240a772428cc2e20d8fd86c9ddbb886bbaff2";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };
    in
    {
      overlays.default = final: _prev: {
        flclashx = self.packages.${final.stdenv.hostPlatform.system}.flclashx;
      };

      nixosModules.default = import ./module.nix;

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          core = pkgs.callPackage ./core.nix {
            src = self;
          };
          flclashx = pkgs.callPackage ./package.nix {
            inherit core;
            src = self;
          };
          android = pkgs.callPackage ./android.nix {
            inherit core flclashx;
            src = self;
          };
        in
        {
          inherit flclashx core;
          dependency-attestation = pkgs.callPackage ./attestation.nix { };
          default = flclashx;
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          android-apk = android;
          android-deps = android.mitmCache;
        }
      );

      apps = forAllSystems (
        system:
        {
          default = {
            type = "app";
            program = "${self.packages.${system}.flclashx}/bin/FlClashX";
          };
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          update-android-deps =
            let
              script = self.packages.x86_64-linux.android-deps.updateScript;
            in
            {
              type = "app";
              program = "${script}";
            };
        }
      );

      checks = forAllSystems (system: {
        dependency-attestation = self.packages.${system}.dependency-attestation;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          androidComposition = pkgs.androidenv.composeAndroidPackages {
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
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.flclashx ];
            packages = with pkgs; [
              flutter341
              go_1_26
              nil
              nixfmt
            ];
          };
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          android = pkgs.mkShell {
            packages = with pkgs; [
              flutter341
              go_1_26
              jdk17
              androidSdk
              gradle_8
              git
              cacert
            ];
            ANDROID_HOME = androidHome;
            ANDROID_SDK_ROOT = androidHome;
            ANDROID_NDK_ROOT = "${androidHome}/ndk/28.0.13004108";
            ANDROID_NDK = "${androidHome}/ndk/28.0.13004108";
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
