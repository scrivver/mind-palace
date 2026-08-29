import 'dart:typed_data';

/// Session-scoped cache for file preview resources.
///
/// Prevents repeated network requests when a parent widget rebuilds while a
/// file detail screen is open. The cache is intentionally lightweight and
/// lives only for the current app session.
class PreviewCache {
  final Map<String, Future<String>> _presignedUrls = {};
  final Map<String, Future<Uint8List>> _contentBytes = {};

  /// Returns a cached presigned URL future for [key] or creates one using
  /// [fetch] and stores it.
  Future<String> presignedUrl(String key, Future<String> Function() fetch) {
    return _presignedUrls.putIfAbsent(key, fetch);
  }

  /// Returns cached PDF bytes for [key] or creates the future using [fetch].
  /// Caches raw object bytes. Named for content rather than PDFs because
  /// every preview now fetches bytes: `/storage/*` is behind forward_auth, so
  /// nothing can be handed to a plain URL loader.
  Future<Uint8List> contentBytes(
    String key,
    Future<Uint8List> Function() fetch,
  ) {
    return _contentBytes.putIfAbsent(key, fetch);
  }

  /// Invalidates cached entries for [key]. Called when the underlying file is
  /// deleted or otherwise known to have changed.
  void invalidate(String key) {
    _presignedUrls.remove(key);
    _contentBytes.remove(key);
  }

  /// Clears all cached previews.
  void clear() {
    _presignedUrls.clear();
    _contentBytes.clear();
  }
}
