import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(AIStickerApp());
}

class AIStickerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Sticker Generator',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: HomeScreen(),
    );
  }
}
