{
  lib,
  buildGoModule,
  go_1_26,
  src,
}:

(buildGoModule.override { go = go_1_26; }) {
  pname = "flclashx-core";
  version = "1.19.28";

  inherit src;
  modRoot = "core";
  proxyVendor = true;
  vendorHash = "sha256-uznvjFXHo2fOFhE5IUOOApMUU5uryEb1JQEG6FFuUkQ=";

  env.CGO_ENABLED = 0;

  tags = [ "with_gvisor" ];
  ldflags = [
    "-w"
    "-s"
    "-buildid="
    "-X github.com/metacubex/mihomo/constant.Version=v1.19.28"
  ];

  postBuild = ''
    mv $GOPATH/bin/core $GOPATH/bin/FlClashCore
  '';

  meta = {
    description = "Mihomo core used by FlClashX";
    homepage = "https://github.com/pluralplay/FlClashX";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "FlClashCore";
  };
}
