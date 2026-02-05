
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';


class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  
  Future<bool> isDeviceSupported()
  
  
   async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  
  Future<bool> canCheckBiometrics() 
  
  
  async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

 
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Get user-friendly biometric type name
  Future<String> getBiometricTypeName() async {
    try {
      final biometrics = await getAvailableBiometrics();

      if (biometrics.isEmpty) {
        return 'Biometric Authentication';
      }

      if (biometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (biometrics.contains(BiometricType.iris)) {
        return 'Iris Scan';
      } else {
        return 'Biometric Authentication';
      }
    } catch (e) {
      return 'Biometric Authentication';
    }
  }

  
  Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if device supports biometrics
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        throw BiometricException('Biometric authentication not available');
      }

      // Authenticate
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      // Handle specific platform exceptions
      if (e.code == 'NotAvailable') {
        throw BiometricException(
            'Biometric authentication is not available on this device');
      } else if (e.code == 'NotEnrolled') {
        throw BiometricException(
            'No biometrics enrolled. Please set up Face ID or Fingerprint in device settings');
      } else if (e.code == 'LockedOut') {
        throw BiometricException(
            'Too many failed attempts. Please try again later');
      } else if (e.code == 'PermanentlyLockedOut') {
        throw BiometricException(
            'Biometric authentication is permanently locked. Use device passcode');
      } else {
        throw BiometricException('Authentication failed: ${e.message}');
      }
    } catch (e) {
      throw BiometricException('Unexpected error: ${e.toString()}');
    }
  }

  /// Authenticate for app unlock
  Future<bool> authenticateForAppUnlock() async {
    return await authenticate(
      reason: 'Unlock Enterprise Vault',
      useErrorDialogs: true,
      stickyAuth: true,
    );
  }

  /// Authenticate for vault access
  Future<bool> authenticateForVaultAccess() async {
    return await authenticate(
      reason: 'Access secure vault',
      useErrorDialogs: true,
      stickyAuth: true,
    );
  }

  /// Authenticate for sensitive operation
  Future<bool> authenticateForSensitiveAction(String action) async {
    return await authenticate(
      reason: action,
      useErrorDialogs: true,
      stickyAuth: true,
    );
  }

  /// Stop authentication (cancel current auth)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Ignore errors when stopping
    }
  }
}

/// Custom exception for biometric errors
class BiometricException implements Exception {
  final String message;
  BiometricException(this.message);

  @override
  String toString() => message;
}
