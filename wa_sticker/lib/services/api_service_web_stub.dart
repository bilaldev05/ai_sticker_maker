// Only used on mobile/desktop
import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readFileBytes(File file) async {
  return await file.readAsBytes();
}
