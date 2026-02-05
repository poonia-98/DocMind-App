

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ParsedEntity {
  final String name;        // Display name
  final String identifier;  // Policy / DL / Vehicle / PAN no

  const ParsedEntity({
    required this.name,
    required this.identifier,
  });
}

class ExpiryBadgeData {
  final String label;
  final Color color;

  const ExpiryBadgeData(this.label, this.color);
}

class EntityParser {
  
  static ParsedEntity parse(String raw) {
    if (raw.trim().isEmpty) {
      return const ParsedEntity(name: 'Untitled', identifier: '');
    }

    final clean = raw.replaceAll('–', '-').trim();

    // ── Insurance (INS-XXXX)
    final ins = RegExp(r'(INS[-\w]+)', caseSensitive: false).firstMatch(clean);
    if (ins != null) {
      final num = ins.group(1)!;
      final name = _strip(clean, num);
      return ParsedEntity(
        name: name.isEmpty ? 'Insurance Policy' : name,
        identifier: num,
      );
    }

    // ── Driving License
    final dl = RegExp(r'(DL[-\w]+)', caseSensitive: false).firstMatch(clean);
    if (dl != null) {
      final num = dl.group(1)!;
      final name = _strip(clean, num);
      return ParsedEntity(
        name: name.isEmpty ? 'Driving License' : name,
        identifier: num,
      );
    }

    // ── Vehicle Registration (INDIA)
    final vehicle =
        RegExp(r'([A-Z]{2}\s?\d{1,2}\s?[A-Z]{1,3}\s?\d{3,4})')
            .firstMatch(clean);
    if (vehicle != null) {
      final num = vehicle.group(1)!;
      final name = _strip(clean, num);
      return ParsedEntity(
        name: name.isEmpty ? 'Vehicle' : name,
        identifier: num,
      );
    }

    // ── PAN
    final pan = RegExp(r'([A-Z]{5}\d{4}[A-Z])').firstMatch(clean);
    if (pan != null) {
      final num = pan.group(1)!;
      final name = _strip(clean, num);
      return ParsedEntity(
        name: name.isEmpty ? 'PAN Card' : name,
        identifier: num,
      );
    }

    // ── Passport
    final passport = RegExp(r'([A-Z]\d{7})').firstMatch(clean);
    if (passport != null) {
      final num = passport.group(1)!;
      final name = _strip(clean, num);
      return ParsedEntity(
        name: name.isEmpty ? 'Passport' : name,
        identifier: num,
      );
    }

    // ── Fallback (name only)
    return ParsedEntity(
      name: clean,
      identifier: '',
    );
  }

  
  static int? daysUntil(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString())
          .difference(DateTime.now())
          .inDays;
    } catch (_) {
      return null;
    }
  }

  static ExpiryBadgeData expiryBadge(int? days) {
    if (days == null) {
      return ExpiryBadgeData('Active', AppColors.success);
    }
    if (days < 0) {
      return ExpiryBadgeData('Expired', AppColors.error);
    }
    if (days == 0) {
      return ExpiryBadgeData('Today', AppColors.error);
    }
    if (days <= 3) {
      return ExpiryBadgeData('In $days days', AppColors.warning);
    }
    if (days <= 30) {
      return ExpiryBadgeData('In $days days', AppColors.info);
    }
    return ExpiryBadgeData('Active', AppColors.success);
  }

 
  static String _strip(String raw, String remove) {
    return raw
        .replaceAll(remove, '')
        .replaceAll('-', '')
        .trim();
  }
}
