// lib/shared/theme/depth_icon_colors.dart

import 'package:flutter/material.dart';

/// Semantic colour presets consumed by [DepthIcon].
/// Each preset ships a primary → secondary gradient and a matching glow colour.
class DepthIconColors {
  // ── Core semantics ─────────────────────────────────────────
  static const DepthIconPreset notification = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6C63FF), Color(0xFFA78BFA)],
    ),
    glow: Color(0x556C63FF),
  );

  static const DepthIconPreset obligation = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    ),
    glow: Color(0x55F59E0B),
  );

  static const DepthIconPreset entity = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF10B981), Color(0xFF34D399)],
    ),
    glow: Color(0x5510B981),
  );

  static const DepthIconPreset expiry = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEF4444), Color(0xFFF87171)],
    ),
    glow: Color(0x55EF4444),
  );

  static const DepthIconPreset payment = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    ),
    glow: Color(0x553B82F6),
  );

  static const DepthIconPreset deadline = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF97316), Color(0xFFFB923C)],
    ),
    glow: Color(0x55F97316),
  );

  static const DepthIconPreset success = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
    ),
    glow: Color(0x5522C55E),
  );

  static const DepthIconPreset dashboard = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    ),
    glow: Color(0x558B5CF6),
  );

  static const DepthIconPreset vehicle = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
    ),
    glow: Color(0x550EA5E9),
  );

  static const DepthIconPreset insurance = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
    ),
    glow: Color(0x55EC4899),
  );

  static const DepthIconPreset license = DepthIconPreset(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
    ),
    glow: Color(0x5514B8A6),
  );

  /// Pick a preset by the obligation/reminder `type` string from the DB.
  static DepthIconPreset forType(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'expiry':
      case 'renewal':
        return expiry;
      case 'payment':
        return payment;
      case 'deadline':
        return deadline;
      case 'vehicle':
        return vehicle;
      case 'insurance':
        return insurance;
      case 'license':
        return license;
      default:
        return notification;
    }
  }
}

/// Immutable container for a gradient + glow pair.
class DepthIconPreset {
  final LinearGradient gradient;
  final Color glow;

  const DepthIconPreset({
    required this.gradient,
    required this.glow,
  });
}