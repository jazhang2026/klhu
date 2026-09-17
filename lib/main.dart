import 'package:flutter/material.dart';
import 'package:klhu/reading_view.dart';

void main() {
  runApp(const KlhuApp());
}

class KlhuApp extends StatelessWidget {
  const KlhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'klhu Read Aloud',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ReadingView(),
    );
  }
}
