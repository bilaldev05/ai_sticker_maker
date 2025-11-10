import 'dart:typed_data';
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  // Voice recording states
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _timer;
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _chunks = [];

  @override
  void dispose() {
    _textController.dispose();
    _timer?.cancel();
    super.dispose();
  }

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
  Future<void> generateVoiceSticker() async {
    if (_isRecording) return;

    final stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'audio': true});

    _chunks.clear();
    _mediaRecorder = html.MediaRecorder(stream);

    // Listen to dataavailable via addEventListener
    _mediaRecorder!.addEventListener('dataavailable', (event) {
      final e = event as html.BlobEvent;
      if (e.data != null) _chunks.add(e.data!);
    });

    // Listen to stop event
    _mediaRecorder!.addEventListener('stop', (event) async {
      if (_chunks.isEmpty) {
        setState(() {
          _isRecording = false;
        });
        return;
      }

      final blob = html.Blob(_chunks, 'audio/wav');
      setState(() => isLoading = true);
      final stickerBytes = await ApiService.generateStickerFromVoice(blob);
      setState(() {
        _stickerBytes = stickerBytes;
        _isRecording = false;
        isLoading = false;
      });
    });

    _mediaRecorder!.start();
    _startTimer();
    setState(() => _isRecording = true);
  }

  void stopWebRecording() {
    if (_mediaRecorder != null && _isRecording) {
      _mediaRecorder!.stop();
      _timer?.cancel();
      _recordSeconds = 0;
      setState(() => _isRecording = false);
    }
  }

  void _startTimer() {
    _recordSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordSeconds++);
    });
  }

  String get _formattedTime {
    final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  label: Text(_isRecording ? _formattedTime : "Record Voice"),
                  onPressed: _isRecording ? stopWebRecording : generateVoiceSticker,
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
