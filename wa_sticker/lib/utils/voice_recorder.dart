import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorder {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  static Future<File?> recordVoice(BuildContext context) async {
    await _recorder.openRecorder();
    Directory tempDir = await getTemporaryDirectory();
    String filePath = '${tempDir.path}/voice_record.aac';

    bool recording = false;
    File? recordedFile;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Hold to Record"),
        content: GestureDetector(
          onLongPressStart: (_) async {
            await _recorder.startRecorder(toFile: filePath);
            recording = true;
          },
          onLongPressEnd: (_) async {
            if (recording) {
              await _recorder.stopRecorder();
              recordedFile = File(filePath);
              recording = false;
              Navigator.pop(context);
            }
          },
          child: Container(
            height: 100,
            color: Colors.grey[300],
            child: Center(child: Text("Press and hold to record")),
          ),
        ),
      ),
    );

    await _recorder.closeRecorder();
    return recordedFile;
  }
}
