// Conditional export: saving bytes the user already holds, since /storage/* is
// behind forward_auth and a browser navigation to a presigned URL carries no
// bearer token.
export 'save_file_native.dart' if (dart.library.html) 'save_file_web.dart';
