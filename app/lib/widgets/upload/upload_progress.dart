class UploadProgress {
  final String status;
  final double? fraction;
  final bool done;
  final bool error;
  final bool isDuplicate;

  const UploadProgress({
    required this.status,
    this.fraction,
    this.done = false,
    this.error = false,
    this.isDuplicate = false,
  });
}
