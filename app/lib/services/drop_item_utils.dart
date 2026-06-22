// Conditional export for platform-specific drop item helpers.
export 'drop_item_utils_stub.dart'
    if (dart.library.io) 'drop_item_utils_io.dart';
