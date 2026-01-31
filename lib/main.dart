// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import 'core/config.dart';
import 'core/security/vault_encryption_service.dart';
import 'features/settings/settings_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // ⚙️ Initialize Settings
  final settingsService = SettingsService();
  await settingsService.init();

  // 🔒 Initialize Vault Encryption
  final vaultEncryption = VaultEncryptionService();
  await vaultEncryption.initializeKeys();

  // 🧱 (Optional / Future) Blockchain Audit Init
  // final blockchainAudit = BlockchainAudit();
  // await blockchainAudit.initialize();

  // 📱 Lock orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 🎨 System UI styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 🚀 Run App
  runApp(const EnterpriseApp());
}
