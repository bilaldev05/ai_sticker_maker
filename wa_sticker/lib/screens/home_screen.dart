import 'dart:typed_data';
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/sticker_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  Uint8List? _stickerBytes;
  bool isLoading = false;

  

  /// ----------------------------
  /// Text → Sticker
  /// ----------------------------
  Future<void> generateTextSticker() async {
    if (_textController.text.isEmpty) return;
    setState(() => isLoading = true);
    final bytes = await ApiService.generateStickerFromText(_textController.text);
    setState(() {
      _stickerBytes = bytes;
      isLoading = false;
    });
  }

  /// ----------------------------
  /// Image → Sticker
  /// ----------------------------
  Future<void> generateImageSticker() async {
    final htmlInput = html.FileUploadInputElement()..accept = 'image/*';
    htmlInput.onChange.listen((_) async {
      final file = htmlInput.files?.first;
      if (file == null) return;
      setState(() => isLoading = true);

      final stickerBytes = await ApiService.generateStickerFromImage(file);
      setState(() {
        _stickerBytes = stickerBytes;
        isLoading = false;
      });
    });
    htmlInput.click();
  }

  /// ----------------------------
  /// Voice → Sticker (Web)
  /// ----------------------------
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("AI Sticker Generator"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Enter text for sticker",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: generateTextSticker,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.image),
                  label: const Text("Upload Image"),
                  onPressed: generateImageSticker,
                ),
               
              ],
            ),
            const SizedBox(height: 30),
            if (isLoading)
              const CircularProgressIndicator()
            else if (_stickerBytes != null)
              StickerCard(stickerBytes: _stickerBytes!),
          ],
        ),
      ),
    );
  }
}
