import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/utils/haptics.dart';
import '../../announcements/presentation/providers/announcements_provider.dart';
import '../../culture/presentation/providers/events_provider.dart';
import '../../favorites/presentation/providers/favorites_provider.dart';
import '../../places/presentation/providers/places_provider.dart';
import '../../recipes/presentation/providers/recipes_provider.dart';
import '../../routes/presentation/providers/routes_provider.dart';
import '../data/models/chat_message.dart';
import 'providers/chatbot_provider.dart';
import 'widgets/inline_card.dart';
import 'widgets/message_bubble.dart';
import 'widgets/quick_reply_chip.dart';
import 'widgets/typing_indicator.dart';

/// Tam ekran sohbet rotası — `/chatbot`.
///
/// **UX kararları:**
/// - Üstte sade AppBar: avatar + "Samsun Asistan" başlığı + "sohbeti sil" eylemi.
/// - Mesajlar ters-scroll (ListView reverse: true) — yeni mesaj alta gelir.
/// - Klavye açıldığında input bar yukarı kayar (Scaffold default).
/// - 350ms typing delay → cevap doğal hissetsin, anında pop etmesin.
class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Açılış analytics (sadece event adı — içerik yok, KVKK §6.9.6).
      try {
        ref
            .read(analyticsServiceProvider)
            .track(AnalyticsEvents.chatbotOpened);
      } catch (_) {/* sessizce yut */}

      // PRE-WARM: Handler'ların ihtiyaç duyacağı tüm provider'ları tetikle.
      // Hepsi `build()` içinde Future.microtask ile load() çağırır — biz sadece
      // read ederek bu microtask'leri başlatıyoruz. Kullanıcı ilk soruyu sorana
      // kadar veri büyük ihtimalle hazır olur.
      try {
        ref.read(placesProvider);
        ref.read(eventsListProvider);
        ref.read(routesProvider);
        ref.read(announcementsProvider);
        ref.read(recipesProvider);
        ref.read(favoritesProvider);
      } catch (_) {/* read sırasında sessizce geç — handler kendisi de bekler */}
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? overrideText]) {
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty) return;
    Haptics.light();
    ref.read(chatbotProvider.notifier).sendMessage(text);
    _input.clear();
    _scrollToBottom();
  }

  // Quick reply tap handling `_MessageWithExtras` içinde yapılıyor —
  // `_MessageWithExtras` ayrı `ConsumerWidget` olduğundan inline tutuldu.

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Mesaj listesi değiştiğinde scrollü dibe çek
    ref.listen(chatbotProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: _buildAppBar(context, colorScheme),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final msg = state.messages[index];
                  return _MessageWithExtras(message: msg);
                },
              ),
            ),
            _InputBar(
              controller: _input,
              focus: _focus,
              enabled: !state.isProcessing,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme cs) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.tertiary],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Samsun Asistan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Şehir rehberin',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Sohbeti temizle',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _confirmClear(context),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sohbeti temizle?'),
        content: const Text(
          'Bu sohbetteki tüm mesajlar silinecek. Geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(chatbotProvider.notifier).clearConversation();
    }
  }
}

/// Mesaj + (varsa) kartlar + quick reply'ları tek pakette gösterir.
class _MessageWithExtras extends ConsumerWidget {
  const _MessageWithExtras({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isTyping) return const TypingIndicator();

    final payload = message.payload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text.isNotEmpty) MessageBubble(message: message),
        if (message.hasCards)
          ...payload!.cards.map((c) => InlineCard(card: c)),
        if (payload?.followUpHint != null) _FollowUpHint(text: payload!.followUpHint!),
        if (message.hasQuickReplies)
          QuickReplyStrip(
            replies: payload!.quickReplies,
            onSelected: (r) {
              Haptics.light();
              if (r.isNavigation) {
                // Chatbot route shell DIŞINDA olduğundan push yerine go
                // kullanıyoruz — push yaparsak Shell key collision olur
                // ("keyReservation.contains(key)" assertion).
                context.go(r.navigateTo!);
                return;
              }
              ref.read(chatbotProvider.notifier).sendQuickReply(r);
            },
          ),
      ],
    );
  }
}

class _FollowUpHint extends StatelessWidget {
  const _FollowUpHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxxl + AppSpacing.xs,
        right: AppSpacing.lg,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pre-fill örnek sorular — input boşken her dakika rotate olur, kullanıcıya
/// chatbot'un yeteneklerini imrendirir.
const List<String> _kExampleHints = [
  'Bir şey sorun…',
  'Örnek: Yakınımda ne var?',
  'Örnek: Tarihi yerler öner',
  'Örnek: Hafta sonu etkinlikler',
  'Örnek: Samsun yöresel yemekleri',
  'Örnek: Atatürk Anıtı hakkında bilgi',
  'Örnek: Gezi planı oluştur',
];

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final VoidCallback onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  int _hintIndex = 0;

  @override
  void initState() {
    super.initState();
    // Her 4 saniyede bir farklı örnek hint göster (kullanıcı boş bırakırsa).
    _scheduleHintRotation();
  }

  void _scheduleHintRotation() {
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (widget.controller.text.isEmpty && !widget.focus.hasFocus) {
        setState(() => _hintIndex = (_hintIndex + 1) % _kExampleHints.length);
      }
      _scheduleHintRotation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focus,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? _kExampleHints[_hintIndex]
                      : 'Cevap hazırlanıyor…',
                  filled: true,
                  fillColor:
                      cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: widget.enabled
                ? cs.primary
                : cs.primary.withValues(alpha: 0.4),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: widget.enabled ? widget.onSend : null,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
