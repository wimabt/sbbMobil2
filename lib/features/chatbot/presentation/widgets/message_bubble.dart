import 'package:flutter/material.dart';

import '../../../../core/design/design_tokens.dart';
import '../../data/models/chat_message.dart';

/// Sohbet baloncuğu — kullanıcı ve bot için farklı stil.
///
/// **Tasarım kararı:** Bot baloncuğu surface tonunda, kullanıcı baloncuğu
/// primary container. Sol kenarda bot avatar (sparkle). Maks %78 ekran
/// genişliği — tek satırda kalmasın, ama tüm ekranı da kaplamasın.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width * 0.78;

    final bg = isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final fg = isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? AppSpacing.xxxl : AppSpacing.lg,
        right: isUser ? AppSpacing.lg : AppSpacing.xxxl,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _BotAvatar(colorScheme: colorScheme),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.xl),
                    topRight: const Radius.circular(AppRadius.xl),
                    bottomLeft: Radius.circular(
                      isUser ? AppRadius.xl : AppRadius.sm,
                    ),
                    bottomRight: Radius.circular(
                      isUser ? AppRadius.sm : AppRadius.xl,
                    ),
                  ),
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}
