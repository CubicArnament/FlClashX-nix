# FlClashX-nix

[Русский](README.md) | [English](README_EN.md)

[pluralplay/FlClashX](https://github.com/pluralplay/FlClashX) жобасының Nix
flake fork-ы. Бұл fork тек Linux/NixOS және Android үшін жасалған; Windows,
macOS және iOS қолдау көрсетілмейді. Қолданба коды, лицензиясы және бастапқы
авторлары [upstream жобасында](https://github.com/pluralplay/FlClashX) берілген.

Бұл upstream-тің ресми дистрибутиві емес және оның атынан қайырымдылық
қабылдамайды. APK release жарияланбайды: Android derivation тек
қайталанатын Nix құрастыруы мен тексеруі үшін қолданылады.

## Мүмкіндіктер

- `x86_64-linux` және `aarch64-linux` үшін Linux desktop пакеті.
- `programs.flclashx.enable` NixOS модулі.
- `x86_64-linux` host-та Android ортасы және universal APK derivation;
  `armeabi-v7a`, `arm64-v8a`, `x86_64` ABI қолданылады.
- Nix, Pub, Go және Maven/Gradle тәуелділіктері бекітілген.
- Nix lint және аттестациямен автоматты upstream-sync pull request-і.

## NixOS орнату

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

## Тексеру

```bash
nix flake check --no-build
nix build .#flclashx --dry-run
nix build .#android-apk --dry-run
```

Бұл Android тексеруі APK құрмайды. Командалар мен lock-файлдарын әдейі
жаңарту нұсқаулығы [COMMANDS.md](COMMANDS.md) ішінде.

## Аттестация

`nix flake check --no-build` lock-файлдар құрылымын және ішкі хештерін
тексереді. `main` ішіндегі әр push үшін GitHub Actions тек Nix жасаған JSON
аттестация есебі бар уақытша Release құрады. Ол жеті күннен кейін жойылады;
APK не басқа бинарник жарияланбайды.

## Лицензия

Осы fork-тің Nix коды жоба кодымен бірге [GPL-3.0-only](LICENSE) шарттарымен
таратылады. Upstream лицензиялық хабарламаларын да қараңыз.
