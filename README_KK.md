# FlClashX

[Русский](README.md) | [English](README_EN.md)

FlClashX - ClashMeta негізіндегі ашық бастапқы коды бар, жарнамасыз прокси
клиенті. Бұл fork тек Linux desktop және Android платформаларын қолдайды.

## Мүмкіндіктер

- Clash/Mihomo конфигурациялары мен жазылымдарын басқару.
- Android VPN және Linux TUN/system proxy режимдері.
- QR-код арқылы жазылым қосу, прокси мен профильдерді басқару.
- Android TV, жоғары жаңарту жиілікті Android дисплейлері және Remnawave
  тақта интеграциясы.

## NixOS және құрастыру

Nix flake Flutter, Go, Android SDK/NDK және Gradle нұсқаларын бекітеді.
Linux desktop `x86_64-linux` және `aarch64-linux` жүйелерінде қолжетімді.
Android universal APK тек `x86_64-linux` хостында құрастырылады және
`armeabi-v7a`, `arm64-v8a`, `x86_64` ABI нұсқаларын қамтиды.

Барлық командалар, тәуелділік lock-файлдарын жаңарту және NixOS модулін қосу
туралы нұсқаулық: [COMMANDS.md](COMMANDS.md).

## Android әрекеттері

```text
com.follow.clashx.action.START
com.follow.clashx.action.STOP
com.follow.clashx.action.CHANGE
```

Толық пайдаланушы нұсқаулығы, жазылымның custom header-лері мен YAML
параметрлері әзірше [орысша](README.md) және [ағылшынша](README_EN.md)
құжаттарында берілген.
