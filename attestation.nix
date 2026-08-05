{
  lib,
  runCommand,
}:
let
  flakeLock = builtins.fromJSON (builtins.readFile ./flake.lock);
  pubLock = builtins.fromJSON (builtins.readFile ./pubspec-lock.json);
  gradleLock = builtins.fromJSON (builtins.readFile ./gradle-deps.json);
  wrapper = builtins.readFile ./android/gradle/wrapper/gradle-wrapper.properties;
  isHexHash = hash: builtins.isString hash && builtins.match "[0-9a-f]{64}" hash != null;
  isSRIHash = hash: builtins.isString hash && builtins.match "sha256-[A-Za-z0-9+/]{43}=" hash != null;
  validGradleEntry = value:
    if builtins.isAttrs value then lib.all validGradleEntry (builtins.attrValues value) else isSRIHash value;
  gradleRepositories = builtins.filter (name: lib.substring 0 1 name != "!") (builtins.attrNames gradleLock);
  validPubPackage = package:
    package.source != "hosted" || (package.description ? sha256 && isHexHash package.description.sha256);
in
assert flakeLock.nodes ? nixpkgs;
assert flakeLock.nodes.nixpkgs.locked ? narHash;
assert isSRIHash flakeLock.nodes.nixpkgs.locked.narHash;
assert flakeLock.nodes.nixpkgs.locked ? rev;
assert builtins.match "[0-9a-f]{40}" flakeLock.nodes.nixpkgs.locked.rev != null;
assert builtins.length gradleRepositories > 0;
assert lib.all (name: validGradleEntry gradleLock.${name}) gradleRepositories;
assert lib.all validPubPackage (builtins.attrValues pubLock.packages);
assert lib.any (line: builtins.match "distributionUrl=.*gradle-[0-9.]+-(all|bin)[.]zip" line != null) (lib.splitString "\n" wrapper);
runCommand "flclashx-dependency-attestation" { } "touch $out"
