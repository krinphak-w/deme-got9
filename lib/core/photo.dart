import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_service.dart';

// Shared photo helpers (profile avatars, product shots, PGS log photos).
// Web note: bytes are kept in memory for display; temp-file paths only
// persist on mobile/desktop. Supabase Storage is used when keys exist.

/// Pick an image then downscale/re-encode until under 2MB.
Future<Uint8List?> pickCompressedPhoto(ImageSource source) async {
  final XFile? shot =
      await ImagePicker().pickImage(source: source, maxWidth: 1600);
  if (shot == null) return null;
  final Uint8List raw = await shot.readAsBytes();
  return compute(_compressTo2Mb, raw);
}

/// Store [bytes] and return a path/URL for the DB column.
/// [bucket] + [objectName] are used for Supabase Storage when online.
Future<String?> storePhoto(
  Uint8List bytes, {
  required String bucket,
  required String objectName,
}) async {
  if (Supa.isMock) {
    if (kIsWeb) return 'memory:$objectName'; // display from memory cache
    final Directory dir = await getTemporaryDirectory();
    final File f = File('${dir.path}/$objectName');
    await f.writeAsBytes(bytes);
    return f.path;
  }
  final SupabaseClient client = Supa.client;
  await client.storage.from(bucket).uploadBinary(objectName, bytes,
      fileOptions: const FileOptions(
          contentType: 'image/jpeg', upsert: true));
  return client.storage.from(bucket).getPublicUrl(objectName);
}

/// Downscale + re-encode JPEG until under 2MB (background isolate).
Uint8List compressTo2Mb(Uint8List raw) => _compressTo2Mb(raw);

Uint8List _compressTo2Mb(Uint8List raw) {
  img.Image? image = img.decodeImage(raw);
  if (image == null) return raw;
  int quality = 85;
  Uint8List out =
      Uint8List.fromList(img.encodeJpg(image, quality: quality));
  while (out.lengthInBytes > 2 * 1024 * 1024 && quality > 30) {
    quality -= 10;
    out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
  if (out.lengthInBytes > 2 * 1024 * 1024) {
    final img.Image small = img.copyResize(image, width: 1280);
    out = Uint8List.fromList(img.encodeJpg(small, quality: 75));
  }
  return out;
}
