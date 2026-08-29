import 'package:file_picker/file_picker.dart';

/// A file chosen for upload, paired with where it sat inside the folder the
/// user picked or dropped.
///
/// [relativePath] exists because [PlatformFile.path] cannot carry this: on
/// native it holds the absolute filesystem path, which byte reading depends on,
/// while on web it is either a browser-relative path or null. Sending a
/// filesystem path to Reliquary would create folders named after the user's
/// home directory, so this field is only ever set to a genuinely relative path.
class PickedFile {
  final PlatformFile file;

  /// Path relative to the upload root, including the chosen folder's own name,
  /// e.g. `Photos/2026/a.jpg`. Null for a plain file selection.
  final String? relativePath;

  const PickedFile(this.file, {this.relativePath});

  String get name => file.name;

  int get size => file.size;
}

/// Strips directories from a path, tolerating either separator.
String basenameOfPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash == -1 ? normalized : normalized.substring(slash + 1);
}
