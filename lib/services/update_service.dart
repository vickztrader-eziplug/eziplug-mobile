import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'debug_logger.dart';

class UpdateService {
  /// Checks for Google Play Store updates and handles the update flow.
  /// Uses Flexible update by default, but falls back to Immediate if required.
  static Future<void> checkForUpdates() async {
    // In-App Updates are only supported on Android.
    if (!Platform.isAndroid || kIsWeb) return;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        debugLogger.log('UPDATE_SERVICE', 'Update available. Priority: ${updateInfo.updatePriority}, Flexible=${updateInfo.flexibleUpdateAllowed}, Immediate=${updateInfo.immediateUpdateAllowed}');

        // Priority ranges from 0 to 5. 4 or 5 is a critical update.
        if (updateInfo.updatePriority >= 4 && updateInfo.immediateUpdateAllowed) {
          // Immediate Update: Forces a full-screen block until the app is updated.
          await debugLogger.log('UPDATE_SERVICE', 'Critical update priority detected. Starting Immediate Update...');
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          // Flexible Update: Downloads in the background while the user uses the app.
          await debugLogger.log('UPDATE_SERVICE', 'Starting Flexible Update...');
          AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
          
          if (result == AppUpdateResult.success) {
            await debugLogger.log('UPDATE_SERVICE', 'Flexible Update Downloaded. Prompting user to install...');
            // Prompts the user to install and restart the app.
            await InAppUpdate.completeFlexibleUpdate();
          }
        } else if (updateInfo.immediateUpdateAllowed) {
          // Fallback to Immediate if Flexible is disabled but Immediate is allowed
          await debugLogger.log('UPDATE_SERVICE', 'Flexible not allowed. Starting Immediate Update...');
          await InAppUpdate.performImmediateUpdate();
        }
      } else {
        debugLogger.log('UPDATE_SERVICE', 'No updates available.');
      }
    } catch (e) {
      debugLogger.log('UPDATE_SERVICE', 'Failed to check for updates: $e');
    }
  }
}
