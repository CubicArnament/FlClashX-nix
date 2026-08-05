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
''
