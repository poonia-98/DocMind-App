import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../core/documents/document_list_screen.dart';
import '../../features/life/entities_screen.dart';
import '../../features/vault/vault_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/auth/profile_screen.dart';
import '../../features/auth/login_screen.dart';
import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

class AppSidebar extends StatelessWidget {
  final AuthService _authService = AuthService();

  AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor:
          isDark ? AppColors.surfaceDark : AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enterprise Vault',
                        style: AppTextStyles.h3.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Secure Document Management',
                        style: AppTextStyles.bodySmall
                            .copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(
              color: isDark
                  ? AppColors.dividerDark
                  : AppColors.divider,
            ),

            // ---------------- MENU ----------------
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SidebarItem(
                    icon: Icons.chat_outlined,
                    label: 'Chat',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ChatScreen(),
                        ),
                      );
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const DashboardScreen(),
                        ),
                      );
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.folder_outlined,
                    label: 'Documents',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const DocumentListScreen(),
                        ),
                      );
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.lock_outlined,
                    label: 'Vault',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const VaultScreen(),
                        ),
                      );
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.health_and_safety_outlined,
                    label: 'Life Entities',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const EntitiesScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 32),
                  _SidebarItem(
                    icon: Icons.person_outlined,
                    label: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  _SidebarItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Divider(
              color: isDark
                  ? AppColors.dividerDark
                  : AppColors.divider,
            ),

            // ---------------- LOGOUT ----------------
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SidebarItem(
                icon: Icons.logout,
                label: 'Logout',
                onTap: () async {
                  await _authService.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(),
                      ),
                      (_) => false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimary,
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
