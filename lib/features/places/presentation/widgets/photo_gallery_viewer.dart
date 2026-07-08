import 'package:flutter/material.dart';
import '../../../../core/widgets/full_screen_gallery.dart';

/// Full-screen photo gallery viewer
/// 
/// This is a convenience wrapper around [FullScreenGallery] for backward compatibility.
/// For new implementations, use [FullScreenGallery.open] directly.
class PhotoGalleryViewer extends StatelessWidget {
  const PhotoGalleryViewer({
    super.key,
    required this.photoUrls,
    required this.initialIndex,
    this.heroTag,
  });

  final List<String> photoUrls;
  final int initialIndex;
  
  /// Optional hero tag prefix for image transitions.
  /// Applied as prefix with index appended (e.g. 'gallery_0', 'gallery_1')
  final String? heroTag;

  /// Opens the gallery directly without navigation
  /// Use this when you want to push a route manually
  static Future<void> open({
    required BuildContext context,
    required List<String> photoUrls,
    int initialIndex = 0,
    String? heroTagPrefix,
  }) {
    return FullScreenGallery.open(
      context: context,
      images: photoUrls,
      initialIndex: initialIndex,
      heroTagPrefix: heroTagPrefix,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Directly return FullScreenGallery for in-place usage
    return FullScreenGallery(
      images: photoUrls,
      initialIndex: initialIndex,
      heroTagPrefix: heroTag,
      showThumbnails: photoUrls.length > 1,
    );
  }
}
