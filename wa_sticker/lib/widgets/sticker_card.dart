import 'dart:typed_data';
import 'package:flutter/material.dart';

class StickerCard extends StatelessWidget {
  final Uint8List stickerBytes;

  const StickerCard({super.key, required this.stickerBytes});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.memory(stickerBytes),
      ),
    );
  }
}
