import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../api/api_client.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/widgets/cached_image.dart';
import '../models/map_place.dart';

class PlaceBottomSheet extends StatefulWidget {
  const PlaceBottomSheet({
    super.key,
    required this.place,
    required this.onClose,
    required this.onNavigate,
    required this.onSwipeUp,
  });

  final MapPlace place;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onSwipeUp;

  @override
  State<PlaceBottomSheet> createState() => _PlaceBottomSheetState();
}

class _PlaceBottomSheetState extends State<PlaceBottomSheet> {
  double _dragOffset = 0;
  static const double _swipeThreshold = -80;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dy;
        });
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset < _swipeThreshold ||
            (details.velocity.pixelsPerSecond.dy < -200)) {
          widget.onSwipeUp();
        } else if (_dragOffset > 80) {
          widget.onClose();
        }
        setState(() {
          _dragOffset = 0;
        });
      },
      onTap: widget.onSwipeUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _dragOffset.clamp(-50, 50), 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      _buildPlaceInfo(context),
                      const SizedBox(height: 16),
                      _buildActionButtons(context),
                      const SizedBox(height: 8),
                      _buildHint(context),
                    ],
                  ),
                ),
              ],
            ),
            // Close button at top right
            Positioned(
              top: 4,
              right: 8,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: Theme.of(context).hintColor,
                ),
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withAlpha(76),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPlaceInfo(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlaceImage(context),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryBadge(context),
                  const SizedBox(height: 4),
                  Text(
                    widget.place.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if ((widget.place.description ?? '').isNotEmpty)
                Text(
                  widget.place.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                )
              else if (widget.place.address.isNotEmpty)
                Text(
                  widget.place.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              const SizedBox(height: 8),
              _buildDistanceRow(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceImage(BuildContext context) {
    const config = ApiConfig.prod;
    final baseUrl = config.baseUrl;
    final imageUrl = buildImageUrl(widget.place.imageUrl, baseUrl: baseUrl);
    
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl != null
            ? CachedImage(
                imageUrl: imageUrl,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(12),
              )
            : Icon(
                Icons.place_outlined,
                size: 48,
                color: Theme.of(context).hintColor,
              ),
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context) {
    // Kategori yoksa badge gösterme
    if (widget.place.category == null || widget.place.category!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        widget.place.category!,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildDistanceRow(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    if (widget.place.distance.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Icon(
          Icons.near_me_outlined,
          size: 16,
          color: primaryColor,
        ),
        const SizedBox(width: 4),
        Text(
          widget.place.distance,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.onNavigate,
            icon: Icon(
              Icons.navigation_outlined, 
              size: 18,
              color: isDark ? Colors.black : Colors.white,
            ),
            label: Text(
              'Yol Tarifi',
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: 14,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // External maps button - opens native navigation (Google/Apple Maps)
        InkWell(
          onTap: _launchExternalMaps,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.directions_outlined,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchExternalMaps() async {
    final pos = widget.place.position;
    final lat = pos.latitude;
    final lng = pos.longitude;

    final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng');
    final appleMapsUrl =
        Uri.parse('https://maps.apple.com/?daddr=$lat,$lng');
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildHint(BuildContext context) {
    return Text(
      'Detaylar için yukarı çekin veya dokunun',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).hintColor.withAlpha(128),
            fontSize: 11,
          ),
    );
  }
}

