import 'package:flutter/material.dart';

/// Real-time layout debugger overlay.
///
/// Wrap ANY screen with this widget to see live MediaQuery values floating
/// on-screen. Screen-record while triggering the jank to pinpoint which
/// variable changes at which millisecond.
///
/// Usage:
/// ```dart
/// LayoutDebuggerOverlay(
///   child: ScaffoldShell(child: child),
/// )
/// ```
///
/// **Remove before release!**
class LayoutDebuggerOverlay extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const LayoutDebuggerOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final media = MediaQuery.of(context);
    final padTop = media.padding.top;
    final padBot = media.padding.bottom;
    final height = media.size.height;
    final viewInsetsBot = media.viewInsets.bottom;
    final viewPaddingBot = media.viewPadding.bottom;

    return Stack(
      children: [
        child,
        Positioned(
          top: 100,
          right: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '── LAYOUT DEBUG ──',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'pad.top:      ${padTop.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                    Text(
                      'pad.bot:      ${padBot.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: padBot == 0 ? Colors.red : Colors.greenAccent,
                        fontWeight:
                            padBot == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      'viewPad.bot:  ${viewPaddingBot.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.cyanAccent),
                    ),
                    Text(
                      'viewIns.bot:  ${viewInsetsBot.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                    Text(
                      'screen.h:     ${height.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.lightBlueAccent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
