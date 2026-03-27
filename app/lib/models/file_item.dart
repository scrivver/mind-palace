class FileItem {
  final String key;
  final int size;
  final String contentType;
  final DateTime lastModified;
  final String? thumbnailKey;
  final String? checksum;
  final String? uploadDate;
  final String? originalName;

  FileItem({
    required this.key,
    required this.size,
    required this.contentType,
    required this.lastModified,
    this.thumbnailKey,
    this.checksum,
    this.uploadDate,
    this.originalName,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      key: json['key'] as String,
      size: (json['size'] as num).toInt(),
      contentType:
          (json['content_type'] as String?) ?? 'application/octet-stream',
      lastModified: DateTime.parse(json['last_modified'] as String),
      thumbnailKey: json['thumbnail_key'] as String?,
      checksum: json['checksum'] as String?,
      uploadDate: json['upload_date'] as String?,
      originalName: json['original_name'] as String?,
    );
  }

  String get filename => key.split('/').last;

  String get displayName => originalName ?? filename;

  bool get isImage => contentType.startsWith('image/');

  bool get isVideo => contentType.startsWith('video/');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
