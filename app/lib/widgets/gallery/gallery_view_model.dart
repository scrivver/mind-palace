import '../../models/engram_file.dart';
import '../../utils/format.dart';

enum GalleryViewMode {
  grid('grid'),
  list('list');

  const GalleryViewMode(this.queryValue);

  final String queryValue;

  static GalleryViewMode parse(String? value) {
    return GalleryViewMode.values.firstWhere(
      (mode) => mode.queryValue == value,
      orElse: () => GalleryViewMode.grid,
    );
  }
}

enum GalleryGroupingMode {
  folders('folders'),
  allFiles('all');

  const GalleryGroupingMode(this.queryValue);

  final String queryValue;

  static GalleryGroupingMode parse(String? value) {
    return GalleryGroupingMode.values.firstWhere(
      (mode) => mode.queryValue == value,
      orElse: () => GalleryGroupingMode.allFiles,
    );
  }
}

class GalleryFolderPath {
  final String path;

  GalleryFolderPath([String path = '']) : path = _normalizePath(path);

  const GalleryFolderPath.root() : path = '';

  bool get isRoot => path.isEmpty;

  List<String> get segments => path.isEmpty ? const [] : path.split('/');

  String get name => isRoot ? 'Files' : segments.last;

  GalleryFolderPath child(String name) {
    final clean = _normalizePath(name);
    if (clean.isEmpty) return this;
    return GalleryFolderPath(path.isEmpty ? clean : '$path/$clean');
  }

  GalleryFolderPath parent() {
    final slash = path.lastIndexOf('/');
    if (slash == -1) return const GalleryFolderPath.root();
    return GalleryFolderPath(path.substring(0, slash));
  }

  static String _normalizePath(String value) {
    final normalized = value
        .replaceAll('\\', '/')
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part != '.' && part != '..')
        .join('/');
    return normalized;
  }
}

class FolderEntry {
  final String name;
  final String path;
  final int count;

  const FolderEntry({
    required this.name,
    required this.path,
    required this.count,
  });

  factory FolderEntry.fromJson(Map<String, dynamic> json) {
    return FolderEntry(
      name: json['name'] as String,
      path: json['path'] as String,
      count: (json['file_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class GalleryFileProjection {
  final EngramFile file;
  final String displayPath;
  final String directoryPath;
  final String relativeLabel;

  GalleryFileProjection({
    required this.file,
    required this.displayPath,
    required this.directoryPath,
    required this.relativeLabel,
  });

  String get displayName => basenameOf(displayPath);

  String get typeLabel => shortTypeForMime(file.mimeType ?? '');

  String get sizeLabel => FormatUtils.formatBytes(file.size);

  String get modifiedLabel => FormatUtils.relativeTime(file.mtime);

  factory GalleryFileProjection.fromFile(
    EngramFile file, {
    String currentPath = '',
    bool showFullPath = false,
  }) {
    final displayPath = displayPathForFile(file);
    final directoryPath = parentPathOf(displayPath);
    final normalizedCurrent = GalleryFolderPath._normalizePath(currentPath);
    var relativeLabel = displayPath;
    if (!showFullPath && normalizedCurrent.isNotEmpty) {
      final prefix = '$normalizedCurrent/';
      if (displayPath.startsWith(prefix)) {
        relativeLabel = displayPath.substring(prefix.length);
      }
    } else if (!showFullPath) {
      relativeLabel = displayPath;
    }
    if (relativeLabel.isEmpty) relativeLabel = file.filename;
    return GalleryFileProjection(
      file: file,
      displayPath: displayPath,
      directoryPath: directoryPath,
      relativeLabel: relativeLabel,
    );
  }
}

class GalleryRouteState {
  final String searchQuery;
  final String? selectedType;
  final Set<String> selectedTags;
  final GalleryViewMode viewMode;
  final GalleryGroupingMode groupingMode;
  final GalleryFolderPath folderPath;

  const GalleryRouteState({
    this.searchQuery = '',
    this.selectedType,
    this.selectedTags = const {},
    this.viewMode = GalleryViewMode.grid,
    this.groupingMode = GalleryGroupingMode.allFiles,
    this.folderPath = const GalleryFolderPath.root(),
  });

  factory GalleryRouteState.fromQuery(Map<String, String> query) {
    return GalleryRouteState(
      searchQuery: query['q'] ?? '',
      selectedType: query['type'],
      selectedTags: (query['tags'] ?? '')
          .split(',')
          .where((tag) => tag.isNotEmpty)
          .toSet(),
      viewMode: GalleryViewMode.parse(query['view']),
      groupingMode: GalleryGroupingMode.parse(query['group']),
      folderPath: GalleryFolderPath(query['path'] ?? ''),
    );
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (searchQuery.isNotEmpty) params['q'] = searchQuery;
    if (selectedType != null && selectedType != 'all') {
      params['type'] = selectedType!;
    }
    if (selectedTags.isNotEmpty) {
      params['tags'] = selectedTags.join(',');
    }
    if (viewMode != GalleryViewMode.grid) {
      params['view'] = viewMode.queryValue;
    }
    if (groupingMode != GalleryGroupingMode.allFiles) {
      params['group'] = groupingMode.queryValue;
    }
    if (groupingMode == GalleryGroupingMode.folders &&
        folderPath.path.isNotEmpty) {
      params['path'] = folderPath.path;
    }
    return params;
  }
}

String displayPathForFile(EngramFile file) {
  final filenamePath = _normalizeDisplayPath(file.filename);
  if (filenamePath.contains('/')) return filenamePath;

  final raw = file.filePath.replaceAll('\\', '/');
  final parts = raw
      .split('/')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length > 4 &&
      parts.first == 'files' &&
      _looksLikeYear(parts[2]) &&
      _looksLikeMonth(parts[3])) {
    final stripped = parts.sublist(4).join('/');
    if (stripped.isNotEmpty) return stripped;
  }
  if (parts.length >= 3 && parts.first == 'files') {
    final stripped = parts.sublist(2).join('/');
    if (stripped.isNotEmpty) return stripped;
  }
  // Never synthesize folders from a storage key we do not recognize. A key in
  // the pre-restructure layout (`<user>/<yyyy>/<mm>/<file>`) would otherwise
  // render as a folder tree named after the owner and the upload date.
  if (parts.isNotEmpty) return parts.last;
  return filenamePath.isNotEmpty ? filenamePath : file.filename;
}

String basenameOf(String displayPath) {
  final slash = displayPath.lastIndexOf('/');
  if (slash == -1) return displayPath;
  return displayPath.substring(slash + 1);
}

String _normalizeDisplayPath(String value) {
  return GalleryFolderPath._normalizePath(value);
}

bool _looksLikeYear(String value) {
  return RegExp(r'^\d{4}$').hasMatch(value);
}

bool _looksLikeMonth(String value) {
  return RegExp(r'^\d{2}$').hasMatch(value);
}

String parentPathOf(String displayPath) {
  final slash = displayPath.lastIndexOf('/');
  if (slash == -1) return '';
  return displayPath.substring(0, slash);
}

/// Projects the files Engram returned. Membership is decided server-side — in
/// folder scope the API already returns only the current directory's direct
/// children — so this labels and orders them and filters nothing itself.
///
/// Filtering here would be actively harmful: a row whose `filename` is a bare
/// basename is grouped at the root by the server, while [displayPathForFile]
/// may recover a deeper path from `file_path`. A client-side prefix test would
/// then reject it at the root while no server-derived folder claims it either,
/// and the file would vanish from every directory.
List<GalleryFileProjection> visibleFilesFor({
  required List<EngramFile> files,
  required String currentPath,
  required bool showFullPath,
}) {
  final normalizedCurrent = GalleryFolderPath._normalizePath(currentPath);
  final projections = files
      .map(
        (file) => GalleryFileProjection.fromFile(
          file,
          currentPath: normalizedCurrent,
          showFullPath: showFullPath,
        ),
      )
      .toList();
  projections.sort(
    (a, b) =>
        a.relativeLabel.toLowerCase().compareTo(b.relativeLabel.toLowerCase()),
  );
  return projections;
}

String shortTypeForMime(String mime) {
  if (mime.contains('pdf')) return 'PDF';
  if (mime.startsWith('image/')) return 'IMG';
  if (mime.startsWith('video/')) return 'VID';
  if (mime.startsWith('audio/')) return 'AUD';
  if (mime.contains('zip') || mime.contains('tar') || mime.contains('rar')) {
    return 'ARC';
  }
  if (mime.contains('text') ||
      mime.contains('markdown') ||
      mime.contains('md')) {
    return 'TXT';
  }
  if (mime.contains('javascript') ||
      mime.contains('python') ||
      mime.contains('json') ||
      mime.contains('html') ||
      mime.contains('xml')) {
    return 'CODE';
  }
  return 'FILE';
}
