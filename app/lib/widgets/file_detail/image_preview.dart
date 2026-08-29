import 'dart:typed_data';

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
  Future<Uint8List>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadBytes();
  }

  @override
  void didUpdateWidget(ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.reliquary != widget.reliquary) {
      _bytesFuture = _loadBytes();
    }
  }

  Future<Uint8List> _loadBytes() {
    // /storage/* is behind forward_auth, so the bytes must come through the
    // authenticated client rather than a plain image URL.
    return _cache.contentBytes(
      widget.filePath,
      () => widget.reliquary.fetchContent(widget.filePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isImage) {
      return Center(child: _iconPreview(context));
    }
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              constrained: false,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Image.memory(
                  snap.data!,
                  fit: BoxFit.contain,
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
