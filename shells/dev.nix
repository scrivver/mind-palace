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
    pkgs.xz
    pkgs.clang
  ];

  shellHook = ''
    export CHROME_EXECUTABLE="$(which chromium 2>/dev/null || which google-chrome-stable 2>/dev/null || echo "")"
  '';
}
