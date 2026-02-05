// lib/core/api/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsService {
  final _supabase = Supabase.instance.client;
  SharedPreferences? _prefs;

  // Initialize local storage
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

      // 🔥 EXACT METHOD – YAHI CHAHIYE
  T get<T>(String key, T fallback) {
    if (_prefs == null) return fallback;

    final value = _prefs!.get(key);

    if (value is T) return value;
    return fallback;
  }

  }

  /// Get user preferences from Supabase (stored in auth.users metadata)
  Future<Map<String, dynamic>> getUserPreferences() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get from user metadata
      final metadata = user.userMetadata ?? {};
      final preferences =
          metadata['preferences'] as Map<String, dynamic>? ?? {};

      return {
        // Appearance
        'theme_mode':
            preferences['theme_mode'] ?? 'system', // 'light', 'dark', 'system'

        // Security
        'biometric_enabled': preferences['biometric_enabled'] ?? false,
        'auto_lock_enabled': preferences['auto_lock_enabled'] ?? false,
        'auto_lock_timeout': preferences['auto_lock_timeout'] ?? 300, // seconds
        'vault_extra_lock': preferences['vault_extra_lock'] ?? false,

        // Notifications
        'notifications_enabled': preferences['notifications_enabled'] ?? true,
        'expiry_alerts': preferences['expiry_alerts'] ?? true,
        'overdue_alerts': preferences['overdue_alerts'] ?? true,
        'reminder_alerts': preferences['reminder_alerts'] ?? true,
        'push_notifications': preferences['push_notifications'] ?? false,

        // Privacy
        'analytics_enabled': preferences['analytics_enabled'] ?? false,
        'crash_reporting': preferences['crash_reporting'] ?? true,

        // Chat
        'chat_history_enabled': preferences['chat_history_enabled'] ?? true,
        'save_context': preferences['save_context'] ?? true,
      };
    } catch (e) {
      // Return defaults on error
      return {
        'theme_mode': 'system',
        'biometric_enabled': false,
        'auto_lock_enabled': false,
        'auto_lock_timeout': 300,
        'vault_extra_lock': false,
        'notifications_enabled': true,
        'expiry_alerts': true,
        'overdue_alerts': true,
        'reminder_alerts': true,
        'push_notifications': false,
        'analytics_enabled': false,
        'crash_reporting': true,
        'chat_history_enabled': true,
        'save_context': true,
      };
    }
  }

  /// Update user preferences
  Future<void> updatePreferences(Map<String, dynamic> updates) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get current preferences
      final currentPrefs = await getUserPreferences();

      // Merge updates
      final newPrefs = {...currentPrefs, ...updates};

      // Update user metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            ...user.userMetadata ?? {},
            'preferences': newPrefs,
          },
        ),
      );

      // Also cache locally for offline access
      if (_prefs != null) {
        for (var entry in updates.entries) {
          final key = 'pref_${entry.key}';
          final value = entry.value;

          if (value is bool) {
            await _prefs!.setBool(key, value);
          } else if (value is int) {
            await _prefs!.setInt(key, value);
          } else if (value is double) {
            await _prefs!.setDouble(key, value);
          } else if (value is String) {
            await _prefs!.setString(key, value);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to update preferences: $e');
    }
  }

  /// Get specific preference
  Future<T?> getPreference<T>(String key) async {
    try {
      final prefs = await getUserPreferences();
      return prefs[key] as T?;
    } catch (e) {
      return null;
    }
  }

  /// Set specific preference
  Future<void> setPreference(String key, dynamic value) async {
    await updatePreferences({key: value});
  }

  /// Theme mode helpers
  Future<String> getThemeMode() async {
    return await getPreference<String>('theme_mode') ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    if (!['light', 'dark', 'system'].contains(mode)) {
      throw ArgumentError('Invalid theme mode: $mode');
    }
    await setPreference('theme_mode', mode);
  }

  /// Biometric lock helpers
  Future<bool> isBiometricEnabled() async {
    return await getPreference<bool>('biometric_enabled') ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await setPreference('biometric_enabled', enabled);
  }

  /// Auto lock helpers
  Future<bool> isAutoLockEnabled() async {
    return await getPreference<bool>('auto_lock_enabled') ?? false;
  }

  Future<void> setAutoLockEnabled(bool enabled) async {
    await setPreference('auto_lock_enabled', enabled);
  }

  Future<int> getAutoLockTimeout() async {
    return await getPreference<int>('auto_lock_timeout') ?? 300;
  }

  Future<void> setAutoLockTimeout(int seconds) async {
    await setPreference('auto_lock_timeout', seconds);
  }

  /// Notification helpers
  Future<bool> areNotificationsEnabled() async {
    return await getPreference<bool>('notifications_enabled') ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await setPreference('notifications_enabled', enabled);
  }

  /// Reset all preferences to defaults
  Future<void> resetToDefaults() async {
    await updatePreferences({
      'theme_mode': 'system',
      'biometric_enabled': false,
      'auto_lock_enabled': false,
      'auto_lock_timeout': 300,
      'vault_extra_lock': false,
      'notifications_enabled': true,
      'expiry_alerts': true,
      'overdue_alerts': true,
      'reminder_alerts': true,
      'push_notifications': false,
      'analytics_enabled': false,
      'crash_reporting': true,
      'chat_history_enabled': true,
      'save_context': true,
    });
  }

  /// Export all user data (for GDPR compliance)
  Future<Map<String, dynamic>> exportUserData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // This would be a comprehensive export
      // For now, return basic structure
      return {
        'user_id': userId,
        'preferences': await getUserPreferences(),
        'exported_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to export user data: $e');
    }
  }
}
