import 'dart:typed_data';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000";

  // ---------------------------
  // TEXT → STICKER
  // ---------------------------
  static Future<Uint8List?> generateStickerFromText(String text) async {
    final uri = Uri.parse("$baseUrl/generate_sticker");
    final request = http.MultipartRequest("POST", uri)..fields['text'] = text;

    try {
      final response = await request.send();
      final bytes = await response.stream.toBytes();

      if (response.statusCode == 200) {
        if (_isJsonError(bytes)) return null;
        return bytes;
      } else {
        print("❌ Server returned ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Network error: $e");
      return null;
    }
  }

  // ---------------------------
  // IMAGE → STICKER
  // ---------------------------
  static Future<Uint8List?> generateStickerFromImage(html.File file) async {
    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final bytes = _normalizeBytes(reader.result);
      final uri = Uri.parse("$baseUrl/upload_image");
      final request = http.MultipartRequest("POST", uri);

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: file.name,
        contentType: MediaType('image', 'png'),
      ));

      final response = await request.send();
      final responseBytes = await response.stream.toBytes();

      if (response.statusCode == 200) {
        if (_isJsonError(responseBytes)) return null;
        return responseBytes;
      } else {
        print("❌ Server returned ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Error uploading image: $e");
      return null;
    }
  }

  // ---------------------------
  // VOICE → STICKER
  // ---------------------------
  static Future<Uint8List?> generateStickerFromVoice(html.File file) async {
    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final bytes = _normalizeBytes(reader.result);
      final uri = Uri.parse("$baseUrl/generate_sticker_from_voice");
      final request = http.MultipartRequest("POST", uri);

      request.files.add(http.MultipartFile.fromBytes(
        'voice',
        bytes,
        filename: file.name,
        contentType: MediaType('audio', 'wav'), // adjust if mp3
      ));

      final response = await request.send();
      final responseBytes = await response.stream.toBytes();

      if (response.statusCode == 200) {
        if (_isJsonError(responseBytes)) return null;
        return responseBytes;
      } else {
        print("❌ Server returned ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Error uploading voice: $e");
      return null;
    }
  }

  
  // Helpers
  
  static Uint8List _normalizeBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is ByteBuffer) return Uint8List.view(data);
    throw Exception("Unsupported FileReader result type: ${data.runtimeType}");
  }

  static bool _isJsonError(Uint8List bytes) {
    try {
      final str = String.fromCharCodes(bytes);
      return str.startsWith('{') && str.contains('"error"');
    } catch (_) {
      return false;
    }
  }
}
