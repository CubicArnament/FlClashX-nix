# FlClashX-nix

[English](README_EN.md) | [Қазақша](README_KK.md)

Nix-flake fork клиента [pluralplay/FlClashX](https://github.com/pluralplay/FlClashX).
Проект предназначен только для Linux/NixOS и Android; Windows, macOS и iOS не
поддерживаются. Исходный код приложения, лицензия и авторы указаны в
[upstream-проекте](https://github.com/pluralplay/FlClashX).

Этот репозиторий не является официальным дистрибутивом upstream и не принимает
пожертвования от его имени. Здесь нет APK-релизов: Android derivation служит
для воспроизводимой Nix-сборки и её проверки.

## Возможности

- Nix-пакет Linux desktop для `x86_64-linux` и `aarch64-linux`.
- NixOS-модуль `programs.flclashx.enable`.
- Android окружение и universal APK derivation для `x86_64-linux` host с ABI
  `armeabi-v7a`, `arm64-v8a` и `x86_64`.
- Зафиксированные Nix, Pub, Go и Maven/Gradle зависимости.
- Автоматический upstream-sync через pull request с Nix lint и аттестацией.

## Установка в NixOS

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

## Разработка и проверка

```bash
nix develop
nix flake check --no-build
nix build .#flclashx --dry-run
nix build .#android-apk --dry-run
```

Проверка Android не собирает APK. Полный список команд, включая обновление
зафиксированных зависимостей, приведён в [COMMANDS.md](COMMANDS.md).

## Аттестация

`nix flake check --no-build` проверяет структуру lock-файлов и встроенные хеши.
Для каждого push в `main` GitHub Actions создаёт временный Release только с
Nix-сгенерированным JSON-отчётом аттестации. Такие Releases удаляются через
семь дней; APK и другие бинарники в них не публикуются.

## Лицензия

Nix-код этого fork распространяется вместе с исходным кодом проекта на
условиях [GPL-3.0-only](LICENSE). См. также лицензию и уведомления upstream.
