// lib/shared/widgets/depth_icon.dart

import 'package:flutter/material.dart';
import '../theme/depth_icon_colors.dart';

/// A premium, enterprise-grade icon widget that renders Material [IconData]
/// with colour depth via [ShaderMask] gradient fills and a soft ambient glow
/// layered underneath.  No image assets required — pure widget composition.
///
/// Usage:
/// ```dart
/// DepthIcon(
///   Icons.notifications_active,
///   preset: DepthIconColors.notification,
///   size: 28,
/// )
/// ```
class DepthIcon extends StatelessWidget {
  /// The [IconData] to render (e.g. [Icons.notifications_active]).
  final IconData icon;

  /// Colour preset that supplies the gradient and glow.
  final DepthIconPreset preset;

  /// Rendered size of the icon in logical pixels.  Defaults to 24.
  final double size;

  /// Radius of the soft glow circle behind the icon.
  /// Defaults to [size] × 0.7.
  final double? glowRadius;

  /// Opacity multiplier for the glow layer (0.0–1.0).  Defaults to 0.45.
  final double glowOpacity;

  /// If true, the icon pulses gently (scale 1.0 → 1.08 → 1.0) on mount.
  /// Useful for drawing attention to a single CTA icon.
  final bool pulse;

  const DepthIcon(
    this.icon, {
    super.key,
    required this.preset,
    this.size = 24,
    this.glowRadius,
    this.glowOpacity = 0.45,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowRadius = glowRadius ?? size * 0.7;

    Widget core = Stack(
      alignment: Alignment.center,
      children: [
        // ── Ambient glow ──────────────────────────────────
        Container(
          width: effectiveGlowRadius * 2,
          height: effectiveGlowRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: preset.glow.withOpacity(glowOpacity),
            // Second, softer ring for depth
            boxShadow: [
              BoxShadow(
                color: preset.glow.withOpacity(glowOpacity * 0.5),
                blurRadius: effectiveGlowRadius * 0.9,
                spreadRadius: effectiveGlowRadius * 0.15,
              ),
            ],
          ),
        ),
        // ── Gradient-filled icon ──────────────────────────
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return preset.gradient.createShader(
              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
            );
          },
          blendMode: BlendMode.srcIn,
          child: Icon(
            icon,
            size: size,
            color: Colors.white, // ShaderMask requires a solid base
          ),
        ),
      ],
    );

    if (pulse) {
      return _PulsingWrapper(child: core);
    }
    return core;
  }
}

/// Internal widget that applies a one-shot scale pulse on mount.
class _PulsingWrapper extends StatefulWidget {
  final Widget child;
  const _PulsingWrapper({super.key, required this.child});

  @override
  State<_PulsingWrapper> createState() => _PulsingWrapperState();
}

class _PulsingWrapperState extends State<_PulsingWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 60),
      ],
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Play once after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}

/// Convenience: a circular background tile that wraps a [DepthIcon].
/// Useful for card leading-icon slots.
class DepthIconTile extends StatelessWidget {
  final IconData icon;
  final DepthIconPreset preset;
  final double tileSize;
  final double iconSize;

  const DepthIconTile(
    this.icon, {
    super.key,
    required this.preset,
    this.tileSize = 48,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // Very subtle gradient wash as background
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            preset.glow.withOpacity(0.18),
            preset.glow.withOpacity(0.06),
          ],
        ),
      ),
      child: Center(
        child: DepthIcon(
          icon,
          preset: preset,
          size: iconSize,
          glowOpacity: 0.0, // Tile already provides the background
        ),
      ),
    );
  }
}