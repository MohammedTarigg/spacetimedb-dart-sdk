import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

import 'generated/client.dart';
import 'generated/message.dart';
import 'generated/user.dart';

/// Bridges SpacetimeDB SDK streams to Flutter's [ChangeNotifier].
class SpacetimeDbService extends ChangeNotifier {
  SpacetimeDbClient? _client;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _error;
  bool _disposed = false;
  final List<StreamSubscription> _subscriptions = [];

  String _lastHost = '';
  String _lastDatabase = '';

  // Chat
  List<Message> get messages {
    final list = _client?.message.iter().toList() ?? [];
    list.sort((a, b) => a.sent.compareTo(b.sent));
    return list;
  }

  List<User> get onlineUsers =>
      _client?.user.iter().where((u) => u.online).toList() ?? [];

  Identity? get myIdentity => _client?.identity;

  String displayName(Identity id) {
    final user =
        _client?.user.iter().where((u) => u.identity == id).firstOrNull;
    final name = user?.name ?? '';
    return name.isNotEmpty ? name : id.toAbbreviated;
  }

  // Connection
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get error => _error;
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;

  Future<void> connect({
    required String host,
    required String database,
    bool ssl = false,
  }) async {
    // Clean up any existing connection before reconnecting.
    if (_client != null) {
      await disconnect();
    }

    _lastHost = host;
    _lastDatabase = database;
    _connectionStatus = ConnectionStatus.connecting;
    _error = null;
    notifyListeners();

    try {
      _client = await SpacetimeDbClient.connect(
        host: host,
        database: database,
        ssl: ssl,
        initialSubscriptions: [
          'SELECT * FROM message',
          'SELECT * FROM user',
        ],
      );

      _subscriptions.add(
        _client!.connection.connectionStatus.listen((status) {
          _connectionStatus = status;
          if (!_disposed) notifyListeners();
        }),
      );

      // Debounce stream events to batch delete+insert pairs from the
      // same transaction into a single rebuild.
      bool rebuildScheduled = false;
      void scheduleRebuild(_) {
        if (_disposed || rebuildScheduled) return;
        rebuildScheduled = true;
        Future.microtask(() {
          rebuildScheduled = false;
          if (!_disposed) notifyListeners();
        });
      }

      _subscriptions.add(_client!.message.insertStream.listen(scheduleRebuild));
      _subscriptions.add(_client!.user.insertStream.listen(scheduleRebuild));
      _subscriptions.add(_client!.user.updateStream.listen(scheduleRebuild));
      _subscriptions.add(_client!.user.deleteStream.listen(scheduleRebuild));

      _connectionStatus = _client!.connection.status;
      notifyListeners();
    } catch (e) {
      _connectionStatus = ConnectionStatus.disconnected;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> reconnect() async {
    if (_lastHost.isNotEmpty && _lastDatabase.isNotEmpty) {
      await connect(host: _lastHost, database: _lastDatabase);
    }
  }

  Future<void> sendMessage(String text) async {
    await _client?.reducers.sendMessage(text: text);
  }

  Future<void> setName(String name) async {
    await _client?.reducers.setName(name: name);
  }

  Future<void> disconnect() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _client?.disconnect();
    _client = null;
    _connectionStatus = ConnectionStatus.disconnected;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _client?.disconnect();
    _client = null;
    super.dispose();
  }
}
