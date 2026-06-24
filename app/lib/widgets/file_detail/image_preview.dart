import 'package:flutter/material.dart';

import '../../reliquary_service.dart';
import '../../utils/format.dart';
import '../../utils/preview_cache.dart';

class ImagePreview extends StatefulWidget {
  final String filePath;
  final bool isImage;
  final String? mimeType;
  final String filename;
  final ReliquaryService reliquary;

  const ImagePreview({
    super.key,
    required this.filePath,
    required this.isImage,
    this.mimeType,
    required this.filename,
    required this.reliquary,
  });

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  static final _cache = PreviewCache();
  Future<String>? _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _loadUrl();
  }

  @override
  void didUpdateWidget(ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.reliquary != widget.reliquary) {
      _urlFuture = _loadUrl();
    }
  }

  Future<String> _loadUrl() {
    return _cache.presignedUrl(
      widget.filePath,
      () => widget.reliquary.presignDownload(widget.filePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isImage) {
      return Center(child: _iconPreview(context));
    }
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final pixelRatio = MediaQuery.devicePixelRatioOf(context);
            final cacheWidth = (constraints.maxWidth * pixelRatio).toInt();
            final cacheHeight = (constraints.maxHeight * pixelRatio).toInt();
            return InteractiveViewer(
              constrained: false,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Image.network(
                  snap.data!,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth > 0 ? cacheWidth : null,
                  cacheHeight: cacheHeight > 0 ? cacheHeight : null,
                  errorBuilder: (_, _, _) => _iconPreview(context),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _iconPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconForMime(widget.mimeType ?? ''),
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            widget.filename,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
