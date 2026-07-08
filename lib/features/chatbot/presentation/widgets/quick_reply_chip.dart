import 'package:flutter/material.dart';

import '../../../../core/design/design_tokens.dart';
import '../../data/models/chat_response.dart';

/// Bot mesajının altında gösterilen tıklanabilir chip.
class QuickReplyChip extends StatelessWidget {
  const QuickReplyChip({
    super.key,
    required this.reply,
    required this.onTap,
  });

  final QuickReply reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reply.icon != null) ...[
                Icon(reply.icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Text(
                reply.label,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Birden çok quick reply'ı yatay scroll'la sunan satır.
class QuickReplyStrip extends StatelessWidget {
  const QuickReplyStrip({
    super.key,
    required this.replies,
    required this.onSelected,
  });

  final List<QuickReply> replies;
  final ValueChanged<QuickReply> onSelected;

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxxl + AppSpacing.xs,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final r in replies) ...[
              QuickReplyChip(reply: r, onTap: () => onSelected(r)),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
