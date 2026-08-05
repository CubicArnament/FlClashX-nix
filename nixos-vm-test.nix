{
  dbus,
  flclashx,
  flclashxModule,
  mesa,
  testers,
  xf86videodummy,
}:
testers.nixosTest {
  name = "flclashx-nixos-vm";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ flclashxModule ];
      programs.flclashx = {
        enable = true;
        package = flclashx;
      };
      users.users.flclashx = {
        isNormalUser = true;
        home = "/home/flclashx";
      };
      environment.systemPackages = [
        dbus
        pkgs.coreutils
        mesa.drivers
        pkgs.xdpyinfo
        pkgs.xorgserver
        xf86videodummy
        pkgs.xwininfo
      ];
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("dbus.service")
    machine.succeed("test -x ${flclashx}/bin/FlClashX")
    machine.succeed("test -f ${flclashx}/share/applications/com.follow.clashx.desktop")
    machine.succeed("install -d -o flclashx -g users /home/flclashx/.cache /home/flclashx/.config /home/flclashx/.local/share")
    machine.succeed("cat > /tmp/flclashx-xorg.conf <<'EOF'\nSection \"Files\"\n  ModulePath \"${xf86videodummy}/lib/xorg/modules\"\nEndSection\nSection \"Device\"\n  Identifier \"dummy\"\n  Driver \"dummy\"\n  VideoRam 256000\nEndSection\nSection \"Monitor\"\n  Identifier \"monitor\"\n  HorizSync 28.0-80.0\n  VertRefresh 48.0-75.0\nEndSection\nSection \"Screen\"\n  Identifier \"screen\"\n  Device \"dummy\"\n  Monitor \"monitor\"\n  DefaultDepth 24\n  SubSection \"Display\"\n    Depth 24\n    Modes \"1280x720\"\n  EndSubSection\nEndSection\nEOF")
    machine.succeed("Xorg :99 -config /tmp/flclashx-xorg.conf -nolisten tcp > /tmp/flclashx-xorg.log 2>&1 & echo $! > /tmp/flclashx-xorg.pid")
    machine.succeed("timeout 30 sh -c 'until DISPLAY=:99 xdpyinfo >/dev/null 2>&1; do sleep 1; done' || { cat /tmp/flclashx-xorg.log; exit 1; }")
    machine.succeed("cat > /tmp/flclashx-session <<'EOF'\n#!/bin/sh\nexport DISPLAY=:99\nexport HOME=/home/flclashx\nexport XDG_CACHE_HOME=$HOME/.cache\nexport XDG_CONFIG_HOME=$HOME/.config\nexport XDG_DATA_HOME=$HOME/.local/share\nexport EGL_PLATFORM=x11\nexport GALLIUM_DRIVER=llvmpipe\nexport LIBGL_ALWAYS_SOFTWARE=1\nexport LIBGL_DRIVERS_PATH=${mesa.drivers}/lib/dri\nexport __EGL_VENDOR_LIBRARY_DIRS=${mesa.drivers}/share/glvnd/egl_vendor.d\nstdbuf -oL dbus-monitor --session > /tmp/flclashx-dbus.log 2>&1 &\necho $! > /tmp/flclashx-dbus.pid\nFlClashX > /tmp/flclashx.log 2>&1 &\necho $! > /tmp/flclashx.pid\nwait\nEOF\nchmod 755 /tmp/flclashx-session\nchown flclashx:users /tmp/flclashx-session")
    machine.succeed("su -s /bin/sh -c 'dbus-run-session -- /tmp/flclashx-session > /tmp/flclashx-session.log 2>&1 & echo $! > /tmp/flclashx-session.pid' flclashx")
    machine.succeed("timeout 30 sh -c 'until test -s /tmp/flclashx.pid && kill -0 $(cat /tmp/flclashx.pid); do sleep 1; done'")
    machine.succeed("timeout 30 sh -c 'until su -s /bin/sh -c \"DISPLAY=:99 xwininfo -root -tree | grep -F FlClashX\" flclashx; do test ! -s /tmp/flclashx.pid || kill -0 $(cat /tmp/flclashx.pid) || { cat /tmp/flclashx.log; exit 1; }; sleep 1; done'")
    machine.succeed("timeout 30 sh -c 'until grep -q com.follow.clashx /tmp/flclashx-dbus.log; do sleep 1; done'")
    machine.sleep(10)
    machine.succeed("kill -0 $(cat /tmp/flclashx.pid)")
    machine.succeed("! grep -Ei 'fatal|segmentation fault' /tmp/flclashx.log /tmp/flclashx-session.log")
    machine.succeed("grep -q 'org.freedesktop.DBus.Error.ServiceUnknown' /tmp/flclashx.log")
    machine.succeed("kill $(cat /tmp/flclashx.pid) $(cat /tmp/flclashx-dbus.pid) $(cat /tmp/flclashx-session.pid) $(cat /tmp/flclashx-xorg.pid) || true")
  '';
}
