{
  nixosVmTest,
  runCommand,
}:
runCommand "flclashx-nixos-system-report" { nativeBuildInputs = [ nixosVmTest ]; } ''
  cat > $out <<'EOF'
  # NixOS System Smoke Test

  **Status: passed with headless-session warning**

  This report is produced only after the `flclashx-nixos-vm` NixOS VM test has
  completed successfully.

  ## Tested Environment

  - Clean NixOS QEMU VM without an FHS compatibility layer.
  - `programs.flclashx.enable` installs the packaged application.
  - Isolated non-root user and XDG directories.
  - Headless Xorg dummy driver with Mesa llvmpipe software EGL.
  - Private D-Bus session monitored with `dbus-monitor`.

  ## Assertions

  - The packaged executable and desktop entry exist.
  - The application creates an X11 window named `FlClashX`.
  - The application registers `com.follow.clashx` on the D-Bus session.
  - The application remains alive for at least ten seconds.
  - Application and session logs contain no fatal or segmentation-fault marker.

  ## Warning

  The minimal headless session intentionally has no StatusNotifier watcher.
  FlClashX logs `org.freedesktop.DBus.Error.ServiceUnknown` for that optional
  tray integration, but it creates its X11 window, registers on D-Bus, and
  remains alive for the full test interval. A normal desktop environment
  provides the watcher.

  This is a headless smoke test, not a visual-rendering or end-to-end UI test.
  EOF

  cat >> $out <<'EOF'

  ## Runtime Diagnostics

  > [!IMPORTANT]
  > This section contains parsed, bounded excerpts from the successful VM run.
  > It is diagnostic evidence, not a visual-regression result.

  | Area | Result |
  | --- | --- |
  | GUI | X11 window `FlClashX` was discovered under headless Xorg. |
  | Runtime | Process remained alive for 10 seconds. |
  | D-Bus | `com.follow.clashx` appeared in the private session monitor. |
  | Crash scan | No `fatal` or `segmentation fault` marker was found. |
  EOF
  printf '| GUI diagnostics | %s headless-rendering diagnostics were recorded. |\n' \
    "$(grep -Ec 'WARNING|CRITICAL' ${nixosVmTest}/diagnostics/flclashx.log || true)" >> $out
  printf '| D-Bus warnings | %s missing-desktop-service events were recorded. |\n' \
    "$(grep -Ec 'Error\.(NameHasNoOwner|ServiceUnknown)' ${nixosVmTest}/diagnostics/flclashx-dbus.log || true)" >> $out
  cat >> $out <<'EOF'

  <details>
  <summary><strong>GUI runtime</strong> <code>Flutter/GTK</code> diagnostics</summary>

  ```text
  EOF
  grep -E 'Atk-|appindicator-|WARNING|CRITICAL|ServiceUnknown|ProcessException' ${nixosVmTest}/diagnostics/flclashx.log |
    sed -E 's/[0-9]{2}:[0-9]{2}:[0-9.]+: //; s/\(com\.follow\.clashx:[0-9]+\)/(com.follow.clashx:<pid>)/' |
    sort | uniq -c | sed -E 's/^ *([0-9]+) /[\1x] /' | awk 'NR <= 20' >> $out || true
  cat >> $out <<'EOF'
  ```
  </details>

  <details>
  <summary><strong>D-Bus</strong> application-name registration</summary>

  ```text
  EOF
  grep -A 12 'member=RequestName' ${nixosVmTest}/diagnostics/flclashx-dbus.log |
    sed -E 's/time=[0-9.]+ /time=<redacted> /; s/sender=:[0-9.]+/sender=<app>/' |
    awk 'NR <= 20' >> $out || true
  cat >> $out <<'EOF'
  ```
  </details>

  <details>
  <summary><strong>Xorg</strong> headless display-server startup</summary>

  ```text
  EOF
  grep -E 'X\.Org X Server|X Protocol Version|Current version of pixman|Using config file|Using system config directory|not fatal' ${nixosVmTest}/diagnostics/flclashx-xorg.log |
    sed -E 's#"/nix/store/[^/]*/#"<nix-store>/#; s#"/tmp/[^\"]*"#"<temporary-config>"#' |
    awk 'NR <= 20' >> $out || true
  cat >> $out <<'EOF'
  ```
  </details>
  EOF
''
