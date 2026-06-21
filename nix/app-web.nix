{ pkgs }:

pkgs.flutter.buildFlutterApplication {
  pname = "mind-palace-app-web";
  version = "0.1.0";

  src = ../app;
  targetFlutterPlatform = "web";
  pubspecLock = pkgs.lib.importJSON ../app/pubspec.lock.json;
}
