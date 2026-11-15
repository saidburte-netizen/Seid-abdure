import 'package:flutter_test/flutter_test.dart';

import 'package:brade_and_cake_house/data/upload_validation.dart';

void main() {
  test('accepts the four supported photo types regardless of case', () {
    for (final name in const [
      'photo.jpg',
      'photo.JPEG',
      'photo.png',
      'photo.WebP',
      'avatar.photo.png',
      r'C:\Users\me\photo.jpg',
    ]) {
      expect(
        validateAvatarUpload(fileName: name, byteLength: 1024),
        isNull,
        reason: name,
      );
    }
  });

  test('rejects executable, document and missing extensions', () {
    for (final name in const [
      'payload.exe',
      'photo.gif',
      'contract.pdf',
      'noextension',
      'trailingdot.',
      'photo.jpg.exe',
    ]) {
      expect(
        validateAvatarUpload(fileName: name, byteLength: 1024),
        UploadProblem.unsupportedType,
        reason: name,
      );
    }
  });

  test('rejects empty files and files over five megabytes', () {
    expect(
      validateAvatarUpload(fileName: 'photo.jpg', byteLength: 0),
      UploadProblem.empty,
    );
    expect(
      validateAvatarUpload(fileName: 'photo.jpg', byteLength: -5),
      UploadProblem.empty,
    );
    expect(
      validateAvatarUpload(fileName: 'photo.jpg', byteLength: 5 * 1024 * 1024),
      isNull,
    );
    expect(
      validateAvatarUpload(
        fileName: 'photo.jpg',
        byteLength: 5 * 1024 * 1024 + 1,
      ),
      UploadProblem.tooLarge,
    );
  });

  test('content type follows the extension, defaulting to jpeg', () {
    expect(avatarContentType('png'), 'image/png');
    expect(avatarContentType('webp'), 'image/webp');
    expect(avatarContentType('jpg'), 'image/jpeg');
    expect(avatarContentType('jpeg'), 'image/jpeg');
  });
}
