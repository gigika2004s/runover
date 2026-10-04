import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

final _profilePhotoDataUri = RegExp(
  r'^data:image/(?:jpeg|png|webp);base64,([A-Za-z0-9+/]*={0,2})$',
);

bool isProfilePhotoDataUri(String value) =>
    _profilePhotoDataUri.hasMatch(value);

String? profilePhotoMimeType(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

ImageProvider? profileImageProvider(String? value) {
  final photo = value?.trim();
  if (photo == null || photo.isEmpty) return null;
  if (photo.startsWith('data:')) {
    final match = _profilePhotoDataUri.firstMatch(photo);
    if (match == null) return null;
    try {
      return MemoryImage(Uint8List.fromList(base64Decode(match.group(1)!)));
    } on FormatException {
      return null;
    }
  }
  return NetworkImage(photo);
}
