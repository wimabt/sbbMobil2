import 'package:flutter/material.dart';

/// Reusable tap-to-scale wrapper widget.
/// 
/// Basıldığında child'ı küçülten, bırakıldığında eski haline döndüren
/// ortak animasyon pattern'i. 3+ dosyada tekrarlanan aynı pattern yerine
/// tek bir widget kullanılır.
/// 
/// Kullanım:
/// ```dart
/// ScaleTapWrapper(
///   onTap: () => context.push('/detail'),
///   scaleEnd: 0.97,
///   child: MyCardWidget(),
/// )
/// ```
class ScaleTapWrapper extends StatefulWidget {
  const ScaleTapWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleEnd = 0.97,
    this.duration = const Duration(milliseconds: 150),
  });

  /// Sarılacak widget
  final Widget child;

  /// Tap callback
  final VoidCallback onTap;

  /// Basılı tutulduğunda ulaşılacak scale değeri (varsayılan: 0.97)
  final double scaleEnd;

  /// Animasyon süresi (varsayılan: 150ms)
  final Duration duration;

  @override
  State<ScaleTapWrapper> createState() => _ScaleTapWrapperState();
}

class _ScaleTapWrapperState extends State<ScaleTapWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleEnd).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
