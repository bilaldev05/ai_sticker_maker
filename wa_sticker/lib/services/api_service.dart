import 'dart:typed_data';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000";

  static Future<Uint8List?> generateStickerFromText(String text) async {
    final uri = Uri.parse("$baseUrl/generate_sticker");
    final request = http.MultipartRequest("POST", uri)..fields['text'] = text;
    final response = await request.send();
    if (response.statusCode == 200) {
      return await response.stream.toBytes();
    }
    return null;
  }

  static Future<Uint8List?> generateStickerFromImage(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    // Fix for NativeUint8List vs ByteBuffer
    Uint8List bytes;
    if (reader.result is Uint8List) {
      bytes = reader.result as Uint8List;
    } else if (reader.result is ByteBuffer) {
      bytes = Uint8List.view(reader.result as ByteBuffer);
    } else {
      throw Exception("Unsupported FileReader result type");
    }

    final uri = Uri.parse("$baseUrl/upload_image");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: file.name,
      contentType: MediaType('image', 'png'),
    ));

    final response = await request.send();
    if (response.statusCode == 200) {
      return await response.stream.toBytes();
    }
    return null;
  }

  static Future<Uint8List?> generateStickerFromVoice(html.Blob blob) async {
    if (blob == null) return null;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;

    Uint8List bytes;
    if (reader.result is Uint8List) {
      bytes = reader.result as Uint8List;
    } else if (reader.result is ByteBuffer) {
      bytes = Uint8List.view(reader.result as ByteBuffer);
    } else {
      throw Exception("Unsupported FileReader result type");
    }

    final uri = Uri.parse("$baseUrl/generate_sticker_from_voice");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(http.MultipartFile.fromBytes(
      'voice',
      bytes,
      filename: 'voice.wav',
      contentType: MediaType('audio', 'wav'),
    ));

    final response = await request.send();
    if (response.statusCode == 200) {
      return await response.stream.toBytes();
    }
    return null;
  }
}
