import 'theme_store_native.dart'
    if (dart.library.html) 'theme_store_web.dart';

abstract class ThemeStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

ThemeStore createThemeStore() => ThemeStoreImpl();
