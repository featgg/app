import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Feat.gg',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: Text('Hello Feat.gg'))),
    );
  }
}
