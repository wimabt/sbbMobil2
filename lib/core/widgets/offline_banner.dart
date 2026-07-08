import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';

/// Uygulama çevrimdışıyken ekranın üst kısmında gösterilen ince bant.
///
/// Tamamen animasyonlu: bağlantı kesilince yukarıdan kayar, gelince geri çekilir.
/// `ScaffoldShell`'e entegre edilmiştir — tüm ekranlarda otomatik görünür.
///
/// Tasarım referansı: Gmail ve Google Chrome'un offline banner'ları.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    final isOffline = connectivity.maybeWhen(
      data: (status) => status == AppConnectivity.offline,
      orElse: () => false,
    );

    // IMPORTANT: Slide/opacity transitions don't remove layout space. If we keep
    // the banner in the tree while "hidden", it still reserves height and
    // creates a blank strip at the top. AnimatedSwitcher swaps the child so
    // the banner takes space only when offline.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

        return ClipRect(
          child: SlideTransition(
            position: slide,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: isOffline
          ? const _BannerContent(key: ValueKey('offline'))
          : const SizedBox.shrink(key: ValueKey('online')),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Çevrimdışı — Son kaydedilen veriler gösteriliyor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
