// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

/// Hands already-fetched bytes to the browser as a download. The bytes come
/// from an authenticated request, so no credential travels in a URL.
Future<void> saveBytes(
  String filename,
  Uint8List bytes,
  String contentType,
) async {
  final blob = html.Blob(<Object>[bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = filename
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
