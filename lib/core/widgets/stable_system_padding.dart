import 'package:flutter/material.dart';

/// Prevents background screens from jumping when the OS System Navigation Bar
/// is hidden/shown by full-screen media viewers.
///
/// **Why this works:**
/// When `SystemUiMode.immersiveSticky` hides the OS nav bar, THREE MediaQuery
/// fields change simultaneously:
///   - `padding.bottom` → drops to 0
///   - `viewPadding.bottom` → drops to 0
///   - `size.height` → may increase on some devices
///
/// Flutter's [Scaffold] reads ALL of these internally. If we only freeze
/// `padding`, the Scaffold still reacts to `viewPadding` changes and
/// recalculates its layout — causing the visible jank.
///
/// This widget freezes **both** `padding` and `viewPadding` using a ratchet
/// pattern (remember the max, never decrease), so the background Scaffold
/// is completely blind to OS bar hide/show events.
///
/// **Placement rules:**
/// - ✅ Wrap the [ScaffoldShell] (or whatever holds your tabbed layout).
/// - ❌ Do NOT wrap [MaterialApp] (too high — media screens also need 0 padding).
/// - ❌ Do NOT wrap the media screen itself (it *wants* 0 padding for true full-screen).
class StableSystemPadding extends StatefulWidget {
  final Widget child;
  const StableSystemPadding({super.key, required this.child});

  @override
  State<StableSystemPadding> createState() => _StableSystemPaddingState();
}

class _StableSystemPaddingState extends State<StableSystemPadding> {
  // Ratchet values — only ever increase, never decrease
  double _maxBottomPadding = 0.0;
  double _maxBottomViewPadding = 0.0;

  @override
  Widget build(BuildContext context) {
    final mediaData = MediaQuery.of(context);

    // ── Ratchet: capture the highest values we've ever seen ──
    if (mediaData.padding.bottom > _maxBottomPadding) {
      _maxBottomPadding = mediaData.padding.bottom;
    }
    if (mediaData.viewPadding.bottom > _maxBottomViewPadding) {
      _maxBottomViewPadding = mediaData.viewPadding.bottom;
    }

    // ── Build frozen MediaQuery ──
    final frozenPadding = mediaData.padding.copyWith(
      bottom: _maxBottomPadding > 0 ? _maxBottomPadding : mediaData.padding.bottom,
    );

    final frozenViewPadding = mediaData.viewPadding.copyWith(
      bottom: _maxBottomViewPadding > 0
          ? _maxBottomViewPadding
          : mediaData.viewPadding.bottom,
    );

    return MediaQuery(
      data: mediaData.copyWith(
        padding: frozenPadding,
        viewPadding: frozenViewPadding,
      ),
      child: widget.child,
    );
  }
}
