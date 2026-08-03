# Build Commands

Run Nix commands from the repository root. On Windows, invoke them through
the NixOS WSL distribution:

```powershell
wsl.exe -d NixOS -- bash -lc 'cd /mnt/c/Users/CubicArnament/FlClashX-nix && nix <command>'
```

## Linux

```bash
# Development environment
nix develop

# Build the Linux desktop package
nix build .#flclashx
nix build

# Run the Linux desktop package
nix run
```

The Linux desktop output supports `x86_64-linux` and `aarch64-linux`.

## Android

Android builds require an `x86_64-linux` host. The flake uses Android API 36,
build-tools 36.0.0, NDK 28.0.13004108, CMake 3.22.1, and generates native cores
for `armeabi-v7a`, `arm64-v8a`, and `x86_64`.

```bash
# Android development environment
nix develop .#android

# Record Maven and Gradle artifacts after intentionally changing Android deps
nix run .#update-android-deps

# Build the universal release APK using gradle-deps.json through mitm-cache
nix build .#android-apk -L
```

`gradle-deps.json` is a committed fixed dependency lock. Never replace a
recorded lock with an empty file and do not run its updater unless Android
Gradle dependencies have changed. A successful APK build must resolve Gradle
only through the recorded MITM cache, not the public network.

## Locks

Commit these files whenever their corresponding dependency graph intentionally
changes:

- `flake.lock` for Nix inputs.
- `pubspec.lock` and `pubspec-lock.json` for Flutter/Pub.
- `core/go.sum` and the `vendorHash` in `core.nix` for Go.
- `gradle-deps.json` for Maven/Gradle artifacts.

Validate flake evaluation without building:

```bash
nix flake check --no-build
```

## NixOS Module

Add this flake as an input and enable its module:

```nix
{
  inputs.flclashx.url = "github:<owner>/FlClashX-nix";

  outputs = { self, nixpkgs, flclashx, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        flclashx.nixosModules.default
        {
          programs.flclashx.enable = true;
        }
      ];
    };
  };
}
```
