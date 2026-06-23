import 'package:flutter/material.dart';

import '../../reliquary_service.dart';
import '../../utils/format.dart';

class ImagePreview extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isImage) {
      return FutureBuilder<String>(
        future: reliquary.presignDownload(filePath),
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
                  child: Image.network(
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
    return Center(child: _iconPreview(context));
  }

  Widget _iconPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconForMime(mimeType ?? ''),
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            filename,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
