import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/widgets/circular_icon_button.dart';
import 'models/campaign.dart';
import 'providers/campaigns_provider.dart';

/// docs/mobile_camp.md: Ayrı kampanya detay endpoint'i yoktur.
/// Kampanyaya tıklandığında `type=place` → `/places/:id`,
/// `type=route` → `/routes/:id` açılır.
///
/// Bu ekran, önce listeden kampanyayı bulup hemen yönlendirir.
/// Yükleme sürerken veya kampanya bulunamazsa bilgi kartı gösterir.
class CampaignDetailScreen extends ConsumerStatefulWidget {
  const CampaignDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CampaignDetailScreen> createState() =>
      _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final campaignsState = ref.watch(campaignsProvider);

    // Tüm kampanyalar içinden bu ID'ye sahip olanı bul
    final all = [
      ...campaignsState.activeCampaigns,
      ...campaignsState.completedCampaigns,
    ];

    final Campaign? campaign = all.cast<Campaign?>().firstWhere(
          (c) => c?.id == widget.id,
          orElse: () => null,
        );

    // Veri hazır gelince hemen yönlendir (bir kez)
    //
    // ID Routing:
    //   Route campaigns → navigate with CMS ID (externalRouteId) for content
    //   Place campaigns → navigate with CMS ID (externalPlaceId) for content
    //   The detail providers handle resolving to gamification ID internally.
    if (!_redirected && campaign != null) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (campaign.isRoute) {
          final routeId = campaign.externalRouteId ?? campaign.id;
          context.pushReplacement('/routes/$routeId');
        } else {
          final placeId = campaign.externalPlaceId ?? campaign.id;
          context.pushReplacement('/places/$placeId');
        }
      });
    }

    // Yönlendirme gerçekleşene veya hata oluşana kadar gösterilecek
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.canPop()) context.pop();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: _buildTransitionBody(
          context,
          isDark: isDark,
          isLoading: campaignsState.isLoading,
          campaign: campaign,
        ),
      ),
    );
  }

  Widget _buildTransitionBody(
    BuildContext context, {
    required bool isDark,
    required bool isLoading,
    required Campaign? campaign,
  }) {
    if (campaign != null || isLoading) {
      // Geçiş animasyonlu basit loading kartı
      return _buildLoadingCard(context, isDark);
    }

    // Kampanya bulunamadı
    return _buildNotFound(context, isDark);
  }

  Widget _buildLoadingCard(BuildContext context, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircularIconButton(
              icon: Icons.arrow_back,
              backgroundColor: isDark
                  ? AppColors.darkSurface.withAlpha(230)
                  : Colors.white.withAlpha(230),
              iconColor: isDark ? Colors.white : Colors.black87,
              onPressed: () => context.pop(),
              showShadow: false,
            ),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  Widget _buildNotFound(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 64,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Kampanya bulunamadı',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(context.l10n.btnGoBack),
          ),
        ],
      ),
    );
  }
}
