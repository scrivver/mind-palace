import 'package:file_picker/file_picker.dart';
import 'package:mind_palace/widgets/drop_target_stub.dart';

// Stub implementation for non-IO platforms. Use dynamic typed items so the
// web build does not need the desktop_drop types.
Future<List<PlatformFile>> expandDropItemsIo(List<dynamic> items) async => [];
