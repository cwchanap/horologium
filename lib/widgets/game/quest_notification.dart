import 'dart:async';
import 'package:flutter/material.dart';

class QuestNotification extends StatefulWidget {
  final String questId;
  final String questName;
  final VoidCallback? onDismissed;
  final Duration duration;

  const QuestNotification({
    super.key,
    required this.questId,
    required this.questName,
    this.onDismissed,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<QuestNotification> createState() => _QuestNotificationState();
}

class _QuestNotificationState extends State<QuestNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      if (!mounted) return;
      _controller.reverse().then((_) {
        if (mounted && !_disposed) widget.onDismissed?.call();
      });
    });
  }

  @override
  void didUpdateWidget(covariant QuestNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questId != widget.questId ||
        oldWidget.questName != widget.questName ||
        oldWidget.duration != widget.duration) {
      _dismissTimer?.cancel();
      _controller.forward(from: 0);
      _dismissTimer = Timer(widget.duration, () {
        if (!mounted) return;
        _controller.reverse().then((_) {
          if (mounted && !_disposed) widget.onDismissed?.call();
        });
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.9).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyanAccent, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withAlpha((255 * 0.3).round()),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.cyanAccent, size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quest Complete!',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.questName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
