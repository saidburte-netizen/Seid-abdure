/// Validation for profile-photo uploads.
///
/// Kept out of the widget so the rules can be tested directly and reused if
/// another screen ever uploads a photo.
enum UploadProblem { empty, unsupportedType, tooLarge }

const Set<String> avatarExtensions = {'jpg', 'jpeg', 'png', 'webp'};
const int maxAvatarBytes = 5 * 1024 * 1024;

String avatarContentType(String extension) => switch (extension) {
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'image/jpeg',
};

/// Returns the reason a picked file cannot be uploaded, or `null` when it can.
///
/// The extension is taken from the last dot, never from the whole path, and is
/// compared case-insensitively. A file must be non-empty and at most
/// [maxBytes] bytes.
UploadProblem? validateAvatarUpload({
  required String fileName,
  required int byteLength,
  int maxBytes = maxAvatarBytes,
}) {
  if (byteLength <= 0) return UploadProblem.empty;
  if (byteLength > maxBytes) return UploadProblem.tooLarge;
  final name = fileName.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return UploadProblem.unsupportedType;
  final extension = name.substring(dot + 1).toLowerCase();
  if (!avatarExtensions.contains(extension)) {
    return UploadProblem.unsupportedType;
  }
  return null;
}
