{ pkgs, infraShell }:

pkgs.mkShell {
  name = "mind-palace-dev-shell";
  inputsFrom = [ infraShell ];
  buildInputs = [
    pkgs.flutter
    pkgs.dart
    pkgs.jdk17
    pkgs.android-tools
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.gtk3
    pkgs.glib
    pkgs.sysprof
    pkgs.xz
    pkgs.clang
    pkgs.zenity
    pkgs.libsecret
    pkgs.nodejs
  ];

  shellHook = ''
    export CHROME_EXECUTABLE="$(which chromium 2>/dev/null || which google-chrome-stable 2>/dev/null || echo "")"

    # Prevent nix from leaking CMAKE_INSTALL_PREFIX into Flutter's Linux build,
    # which causes it to try installing to /usr/local/ instead of the build dir.
    unset cmakeFlags
  '';
}
