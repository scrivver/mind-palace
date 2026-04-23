class EngramFile {
  final String id;
  final String filename;
  final int size;
  final String hash;
  final String filePath;
  final String deviceName;
  final String status;
  final String storageType;
  final String? mimeType;
  final int? pageCount;
  final DateTime mtime;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? downloadUrl;
  final String? extractedText;

  EngramFile({
    required this.id,
    required this.filename,
    required this.size,
    required this.hash,
    required this.filePath,
    required this.deviceName,
    required this.status,
    required this.storageType,
    required this.mtime,
    required this.createdAt,
    required this.updatedAt,
    this.mimeType,
    this.pageCount,
    this.tags = const [],
    this.downloadUrl,
    this.extractedText,
  });

  factory EngramFile.fromJson(Map<String, dynamic> json) {
    return EngramFile(
      id: json['id'] as String,
      filename: json['filename'] as String,
      size: (json['size'] as num).toInt(),
      hash: json['hash'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      deviceName: json['device_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      storageType: json['storage_type'] as String? ?? '',
      mimeType: json['mime_type'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      mtime: DateTime.parse(json['mtime'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      downloadUrl: json['download_url'] as String?,
      extractedText: json['extracted_text'] as String?,
    );
  }

  String get displayName => filename;

  bool get isImage => (mimeType ?? '').startsWith('image/');
  bool get isVideo => (mimeType ?? '').startsWith('video/');

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
