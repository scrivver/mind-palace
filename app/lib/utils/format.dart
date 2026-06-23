import 'package:flutter/material.dart';

class FormatUtils {
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes.bitLength / 10).floor().clamp(0, suffixes.length - 1);
    final value = bytes / (1 << (i * 10));
    return '${value.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String relativeTime(DateTime dateTime, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final diff = current.difference(dateTime.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

IconData iconForMime(String mime) {
  if (mime.startsWith('image/')) return Icons.image;
  if (mime.startsWith('video/')) return Icons.videocam;
  if (mime.startsWith('audio/')) return Icons.audiotrack;
  if (mime.contains('pdf')) return Icons.picture_as_pdf;
  if (mime.contains('zip') || mime.contains('archive')) return Icons.archive;
  return Icons.insert_drive_file;
}
