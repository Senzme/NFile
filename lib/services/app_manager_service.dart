import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/app_info_model.dart';

class AppManagerService {
  static const MethodChannel _channel = MethodChannel('com.rubex.nfile/root_shizuku');

  static Future<List<AppInfoModel>> getInstalledApps({bool includeSystem = false}) async {
    try {
      final List<dynamic>? apps = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
        {'includeSystem': includeSystem},
      );
      if (apps == null) return [];
      return apps.map((map) => AppInfoModel.fromMap(Map<dynamic, dynamic>.from(map))).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final Uint8List? iconBytes = await _channel.invokeMethod<Uint8List>(
        'getAppIcon',
        {'packageName': packageName},
      );
      return iconBytes;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> launchApp(String packageName) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'launchApp',
        {'packageName': packageName},
      );
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> openAppDetails(String packageName) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'openAppDetails',
        {'packageName': packageName},
      );
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> uninstallApp(String packageName) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'uninstallApp',
        {'packageName': packageName},
      );
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkUsageStatsPermission() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('checkUsageStatsPermission');
      return success ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestUsageStatsPermission() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('requestUsageStatsPermission');
      return success ?? false;
    } catch (e) {
      return false;
    }
  }
}
