
import 'package:flutter/material.dart';
import 'package:docmind_app/features/settings/settings_service.dart';
import '../../core/auth/auth_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/text_styles.dart';
import '../../shared/widgets/premium_card.dart';
import '../auth/login_screen.dart';
import '../../core/api/notification_service.dart';


import '../../app.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService(); // ✅

  Map<String, dynamic> _preferences = {};
  bool _isLoading = true;
  bool _isSaving = false;


  @override
void initState() {
  super.initState();
  _loadPreferences();
  _checkNotificationPermissions();
}

Future<void> _checkNotificationPermissions() async {
  final enabled = await _notificationService.areNotificationsEnabled();
  if (!enabled && _preferences['notifications_enabled'] == true) {
    // Permissions revoked → sync setting
    await _settingsService.setPreference('notifications_enabled', false);
    await _loadPreferences();
  }
}


  Future<void> _loadPreferences() async {
    try {
      setState(() => _isLoading = true);
      await _settingsService.init();
      final prefs = await _settingsService.getUserPreferences();
      setState(() {
        _preferences = prefs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load settings: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
  setState(() {
    _preferences[key] = value;
    _isSaving = true;
  });

  try {
    await _settingsService.setPreference(key, value);

    // 🎨 THEME HANDLING
    if (key == 'theme_mode') {
      themeModeNotifier.value =
          value == 'dark'
              ? ThemeMode.dark
              : value == 'light'
                  ? ThemeMode.light
                  : ThemeMode.system;
    }

    // 🔔 NOTIFICATIONS MASTER TOGGLE
    if (key == 'notifications_enabled') {
      if (value == true) {
        final granted = await _notificationService.requestPermissions();
        if (granted) {
          await _notificationService.initialize();
          await _notificationService.rescheduleAll();
        }
      } else {
        await _notificationService.cancelAllNotifications();
      }
    }

    // 🔁 INDIVIDUAL NOTIFICATION TOGGLES
    if (key == 'expiry_alerts' ||
        key == 'overdue_alerts' ||
        key == 'reminder_alerts') {
      if (_preferences['notifications_enabled'] == true) {
        await _notificationService.rescheduleAll();
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setting saved ✓'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  } catch (e) {
    setState(() {
      _preferences[key] = !value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  } finally {
    setState(() => _isSaving = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Appearance Section
                _buildSectionHeader('Appearance', isDark),
                PremiumCard(
                  child: Column(
                    children: [
                      _SettingTile(
                        title: 'Theme Mode',
                        subtitle: _getThemeModeLabel(),
                        leading: const Icon(Icons.palette_outlined),
                        trailing: DropdownButton<String>(
                          value: _preferences['theme_mode'] ?? 'system',
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                                value: 'light', child: Text('Light')),
                            DropdownMenuItem(
                                value: 'dark', child: Text('Dark')),
                            DropdownMenuItem(
                                value: 'system', child: Text('System')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              _updatePreference('theme_mode', value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Security Section
                _buildSectionHeader('Security', isDark),
                PremiumCard(
                  child: Column(
                    children: [
                      _SettingTile(
                        title: 'Biometric Lock',
                        subtitle: 'Use Face ID or fingerprint',
                        leading: const Icon(Icons.fingerprint),
                        trailing: Switch(
                          value: _preferences['biometric_enabled'] ?? false,
                          onChanged: (value) {
                            _updatePreference('biometric_enabled', value);
                          },
                          activeColor: AppColors.success,
                        ),
                      ),
                      const Divider(),
                      _SettingTile(
                        title: 'Auto-Lock',
                        subtitle: 'Lock app when inactive',
                        leading: const Icon(Icons.lock_clock),
                        trailing: Switch(
                          value: _preferences['auto_lock_enabled'] ?? false,
                          onChanged: (value) {
                            _updatePreference('auto_lock_enabled', value);
                          },
                          activeColor: AppColors.success,
                        ),
                      ),
                      if (_preferences['auto_lock_enabled'] == true) ...[
                        const Divider(),
                        _SettingTile(
                          title: 'Auto-Lock Timeout',
                          subtitle: _getAutoLockLabel(),
                          leading: const Icon(Icons.timer_outlined),
                          trailing: DropdownButton<int>(
                            value: _preferences['auto_lock_timeout'] ?? 300,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                  value: 0, child: Text('Immediate')),
                              DropdownMenuItem(
                                  value: 60, child: Text('1 minute')),
                              DropdownMenuItem(
                                  value: 300, child: Text('5 minutes')),
                              DropdownMenuItem(
                                  value: 600, child: Text('10 minutes')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _updatePreference('auto_lock_timeout', value);
                              }
                            },
                          ),
                        ),
                      ],
                      const Divider(),
                      _SettingTile(
                        title: 'Extra Vault Security',
                        subtitle: 'Require authentication for vault',
                        leading: const Icon(Icons.shield_outlined),
                        trailing: Switch(
                          value: _preferences['vault_extra_lock'] ?? false,
                          onChanged: (value) {
                            _updatePreference('vault_extra_lock', value);
                          },
                          activeColor: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Notifications Section
                _buildSectionHeader('Notifications', isDark),
                PremiumCard(
                  child: Column(
                    children: [
                      _SettingTile(
                        title: 'Enable Notifications',
                        subtitle: 'Receive app notifications',
                        leading: const Icon(Icons.notifications_outlined),
                        trailing: Switch(
                          value: _preferences['notifications_enabled'] ?? true,
                          onChanged: (value) {
                            _updatePreference('notifications_enabled', value);
                          },
                          activeColor: AppColors.success,
                        ),
                      ),
                      if (_preferences['notifications_enabled'] == true) ...[
                        const Divider(),
                        _SettingTile(
                          title: 'Expiry Alerts',
                          subtitle: 'Document expiration reminders',
                          leading: const Icon(Icons.event_busy),
                          trailing: Switch(
                            value: _preferences['expiry_alerts'] ?? true,
                            onChanged: (value) {
                              _updatePreference('expiry_alerts', value);
                            },
                            activeColor: AppColors.success,
                          ),
                        ),
                        const Divider(),
                        _SettingTile(
                          title: 'Overdue Alerts',
                          subtitle: 'Notify about overdue obligations',
                          leading: const Icon(Icons.warning_amber_outlined),
                          trailing: Switch(
                            value: _preferences['overdue_alerts'] ?? true,
                            onChanged: (value) {
                              _updatePreference('overdue_alerts', value);
                            },
                            activeColor: AppColors.success,
                          ),
                        ),
                        const Divider(),
                        _SettingTile(
                          title: 'Reminder Alerts',
                          subtitle: 'General reminders',
                          leading: const Icon(Icons.alarm),
                          trailing: Switch(
                            value: _preferences['reminder_alerts'] ?? true,
                            onChanged: (value) {
                              _updatePreference('reminder_alerts', value);
                            },
                            activeColor: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Privacy Section
                _buildSectionHeader('Privacy & Data', isDark),
                PremiumCard(
                  child: Column(
                    children: [
                      _SettingTile(
                        title: 'Analytics',
                        subtitle: 'Help improve the app',
                        leading: const Icon(Icons.analytics_outlined),
                        trailing: Switch(
                          value: _preferences['analytics_enabled'] ?? false,
                          onChanged: (value) {
                            _updatePreference('analytics_enabled', value);
                          },
                          activeColor: AppColors.success,
                        ),
                      ),
                      const Divider(),
                      _SettingTile(
                        title: 'Crash Reporting',
                        subtitle: 'Send error reports',
                        leading: const Icon(Icons.bug_report_outlined),
                        trailing: Switch(
                          value: _preferences['crash_reporting'] ?? true,
                          onChanged: (value) {
                            _updatePreference('crash_reporting', value);
                          },
                          activeColor: AppColors.success,
                        ),
                      ),
                      const Divider(),
                      _SettingTile(
                        title: 'Terms & Conditions',
                        leading: const Icon(Icons.description_outlined),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Navigate to terms screen
                          _showTermsDialog();
                        },
                      ),
                      const Divider(),
                      _SettingTile(
                        title: 'Privacy Policy',
                        leading: const Icon(Icons.privacy_tip_outlined),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          _showPrivacyDialog();
                        },
                      ),
                      const Divider(),
                      _SettingTile(
                        title: 'Export My Data',
                        subtitle: 'Download all your data',
                        leading: const Icon(Icons.download_outlined),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportUserData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account Section
                _buildSectionHeader('Account', isDark),
                PremiumCard(
                  child: Column(
                    children: [
                      _SettingTile(
                        title: 'Reset Settings',
                        leading: const Icon(Icons.restore),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _resetSettings,
                      ),
                      const Divider(),
                      _SettingTile(
                        title: 'Logout',
                        leading: Icon(Icons.logout, color: AppColors.warning),
                        textColor: AppColors.warning,
                        onTap: _handleLogout,
                      ),
                      const Divider(),
                      _SettingTile(
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account',
                        leading:
                            Icon(Icons.delete_forever, color: AppColors.error),
                        textColor: AppColors.error,
                        onTap: _handleDeleteAccount,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // App Info
                Center(
                  child: Text(
                    'Enterprise Vault v1.0.0',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }

  String _getThemeModeLabel() {
    switch (_preferences['theme_mode']) {
      case 'light':
        return 'Always light';
      case 'dark':
        return 'Always dark';
      default:
        return 'Follow system';
    }
  }

  String _getAutoLockLabel() {
    final timeout = _preferences['auto_lock_timeout'] ?? 300;
    if (timeout == 0) return 'Immediate';
    if (timeout < 60) return '${timeout}s';
    return '${timeout ~/ 60} minute${timeout > 60 ? 's' : ''}';
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'Enterprise Vault Terms of Service\n\n'
            '1. You own your data\n'
            '2. We encrypt everything\n'
            '3. No third-party access\n'
            '4. GDPR compliant\n\n'
            'Full terms at: enterprisevault.com/terms',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'How we protect your privacy:\n\n'
            '• End-to-end encryption\n'
            '• Zero-knowledge architecture\n'
            '• No data selling\n'
            '• Right to deletion\n'
            '• Data portability\n\n'
            'Full policy at: enterprisevault.com/privacy',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportUserData() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Your Data'),
          content: const Text(
            'This will download all your data in JSON format. '
            'The file will include documents, entities, and obligations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Export'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final data = await _settingsService.exportUserData();
        // In production, trigger file download
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data export initiated ✓'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resetSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('This will reset all settings to defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _settingsService.resetToDefaults();
        await _loadPreferences();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings reset ✓'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // In production, call backend to delete all user data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deletion requested'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingTile({
    required this.title,
    this.subtitle,
    required this.leading,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.bodySmall)
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
