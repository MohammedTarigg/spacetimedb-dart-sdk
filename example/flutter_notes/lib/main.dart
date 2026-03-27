import 'package:flutter/material.dart';

import 'spacetimedb_service.dart';
import 'screens/chat_screen.dart';

const _defaultHost = 'localhost:3000';
const _defaultDatabase = 'notesdb';

const _brandColor = Color(0xFF4F46E5);

final _headerColorScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF1A1B2E),
  brightness: Brightness.dark,
);

void main() {
  runApp(const SpacetimeDbChat());
}

class SpacetimeDbChat extends StatefulWidget {
  const SpacetimeDbChat({super.key});

  @override
  State<SpacetimeDbChat> createState() => _SpacetimeDbChatState();
}

class _SpacetimeDbChatState extends State<SpacetimeDbChat> {
  final _service = SpacetimeDbService();

  @override
  void initState() {
    super.initState();
    _service.connect(host: _defaultHost, database: _defaultDatabase);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpacetimeDB Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _brandColor),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _service,
        builder: (context, _) => ChatScreen(
          service: _service,
          headerColorScheme: _headerColorScheme,
          brandColor: _brandColor,
        ),
      ),
    );
  }
}
