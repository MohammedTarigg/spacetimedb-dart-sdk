import 'package:flutter/material.dart';
import 'package:spacetimedb_dart_sdk/spacetimedb_dart_sdk.dart';

import '../generated/message.dart';
import '../generated/user.dart';
import '../spacetimedb_service.dart';

const _avatarColors = [
  Color(0xFF6366F1),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
];

const _connectedColor = Color(0xFF22C55E);

class ChatScreen extends StatefulWidget {
  final SpacetimeDbService service;
  final ColorScheme headerColorScheme;
  final Color brandColor;

  const ChatScreen({
    super.key,
    required this.service,
    required this.headerColorScheme,
    required this.brandColor,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void didUpdateWidget(ChatScreen old) {
    super.didUpdateWidget(old);
    final count = widget.service.messages.length;
    if (count > _lastMessageCount) {
      _lastMessageCount = count;
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    widget.service.sendMessage(text);
    _inputController.clear();
  }

  void _showSetNameSheet() {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set your name', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Display name',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) {
                Navigator.pop(ctx);
                final name = nameController.text.trim();
                if (name.isNotEmpty) widget.service.setName(name);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) widget.service.setName(name);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.service.messages;
    final onlineUsers = widget.service.onlineUsers;
    final myId = widget.service.myIdentity;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Column(
        children: [
          _ChatHeader(
            colorScheme: widget.headerColorScheme,
            status: widget.service.connectionStatus,
            onlineUsers: onlineUsers,
            myId: myId,
            displayName: widget.service.displayName,
            onSetName: _showSetNameSheet,
          ),
          Expanded(
            child: messages.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMine = myId != null && msg.sender == myId;
                      final showSender = !isMine &&
                          (index == 0 ||
                              messages[index - 1].sender != msg.sender);
                      return _MessageBubble(
                        message: msg,
                        isMine: isMine,
                        showSender: showSender,
                        senderName: widget.service.displayName(msg.sender),
                        timeAgo: _formatTimeAgo(msg.sent.toInt()),
                        brandColor: widget.brandColor,
                      );
                    },
                  ),
          ),
          _MessageInput(
            controller: _inputController,
            onSend: _sendMessage,
            brandColor: widget.brandColor,
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final ColorScheme colorScheme;
  final ConnectionStatus status;
  final List<User> onlineUsers;
  final Identity? myId;
  final String Function(Identity) displayName;
  final VoidCallback onSetName;

  const _ChatHeader({
    required this.colorScheme,
    required this.status,
    required this.onlineUsers,
    required this.myId,
    required this.displayName,
    required this.onSetName,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      ConnectionStatus.connected => _connectedColor,
      ConnectionStatus.connecting ||
      ConnectionStatus.reconnecting =>
        Colors.amber,
      ConnectionStatus.disconnected ||
      ConnectionStatus.authError ||
      ConnectionStatus.fatalError =>
        Colors.red,
    };

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'SpacetimeDB',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusDot(color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      onlineUsers.isEmpty
                          ? status.displayName
                          : '${onlineUsers.length} online',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onlineUsers.isNotEmpty)
                _AvatarStack(
                  users: onlineUsers,
                  myId: myId,
                  displayName: displayName,
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20),
                onPressed: onSetName,
                tooltip: 'Set name',
                style: IconButton.styleFrom(
                  backgroundColor:
                      colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }
}

// ── Avatar Stack ────────────────────────────────────────────────────

class _AvatarStack extends StatelessWidget {
  final List<User> users;
  final Identity? myId;
  final String Function(Identity) displayName;

  const _AvatarStack({
    required this.users,
    required this.myId,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final visible = users.take(4).toList();
    final overflow = users.length - visible.length;

    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < visible.length; i++)
            Transform.translate(
              offset: Offset(-8.0 * i, 0),
              child: _UserAvatar(
                name: displayName(visible[i].identity),
                color: _avatarColors[i % _avatarColors.length],
                isMe: myId != null && visible[i].identity == myId,
              ),
            ),
          if (overflow > 0)
            Transform.translate(
              offset: Offset(-8.0 * visible.length, 0),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                alignment: Alignment.center,
                child: Text('+$overflow',
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final bool isMe;

  const _UserAvatar({
    required this.name,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isMe ? _connectedColor : Colors.black,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48,
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Send the first message',
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}

// ── Message Bubble ──────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool showSender;
  final String senderName;
  final String timeAgo;
  final Color brandColor;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSender,
    required this.senderName,
    required this.timeAgo,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: 4, top: showSender ? 12 : 0),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? brandColor : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.7)
                          : colors.primary,
                    ),
                  ),
                ),
              Text(
                message.text,
                style: TextStyle(
                  color: isMine ? Colors.white : colors.onSurface,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 10,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.5)
                      : colors.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input Bar ───────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Color brandColor;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle:
                      TextStyle(color: colors.outline.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: brandColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 20),
                onPressed: onSend,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────

String _formatTimeAgo(int microseconds) {
  if (microseconds == 0) return '';
  final then = DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
  final diff = DateTime.now().toUtc().difference(then);
  if (diff.inSeconds < 5) return 'now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  return '${diff.inHours}h';
}
