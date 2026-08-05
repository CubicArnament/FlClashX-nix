# FlClashX-nix

[Русский](README.md) | [Қазақша](README_KK.md)

A Nix flake fork of [pluralplay/FlClashX](https://github.com/pluralplay/FlClashX).
It supports Linux/NixOS and Android only; Windows, macOS, and iOS are not
supported. Application source, licensing, and original authors are documented
by the [upstream project](https://github.com/pluralplay/FlClashX).

This is not an official upstream distribution and does not accept donations on
its behalf. It does not publish APK releases: the Android derivation exists for
reproducible Nix builds and validation.

## Features

- Linux desktop package for `x86_64-linux` and `aarch64-linux`.
- NixOS module: `programs.flclashx.enable`.
- Android development environment and universal APK derivation on
  `x86_64-linux`, covering `armeabi-v7a`, `arm64-v8a`, and `x86_64`.
- Pinned Nix, Pub, Go, and Maven/Gradle dependency inputs.
- Automated upstream sync through a pull request with Nix lint and attestation.

## NixOS Installation

```nix
{
  inputs.flclashx.url = "github:CubicArnament/FlClashX-nix";

  outputs = { nixpkgs, flclashx, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        flclashx.nixosModules.default
        { programs.flclashx.enable = true; }
      ];
    };
  };
}
```

## Development and Validation

```bash
nix develop
nix flake check --no-build
nix build .#flclashx --dry-run
nix build .#android-apk --dry-run
```

Android validation does not build an APK. See [COMMANDS.md](COMMANDS.md) for
the full command reference, including intentional dependency-lock updates.

## Attestation

`nix flake check --no-build` validates lock-file structure and embedded hashes.
Every push to `main` creates a temporary GitHub Release containing only a
Nix-generated JSON attestation report. Those releases are removed after seven
days; no APK or other binary is published.

## License

The Nix code in this fork is distributed with the project source under
[GPL-3.0-only](LICENSE). See upstream for its licence notices.
