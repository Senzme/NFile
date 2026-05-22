import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_connection_model.dart';

class NetworkConnectionsService {
  static const String _keyConnections = 'network_connections';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static List<NetworkConnectionModel> getConnections() {
    if (_prefs == null) return [];
    final str = _prefs!.getString(_keyConnections);
    if (str == null || str.isEmpty) return [];
    try {
      final list = json.decode(str) as List<dynamic>;
      return list
          .map((e) => NetworkConnectionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveConnection(NetworkConnectionModel conn) async {
    await init();
    final current = getConnections();
    final index = current.indexWhere((c) => c.id == conn.id);
    if (index >= 0) {
      current[index] = conn;
    } else {
      current.add(conn);
    }
    final str = json.encode(current.map((e) => e.toJson()).toList());
    await _prefs?.setString(_keyConnections, str);
  }

  static Future<void> deleteConnection(String id) async {
    await init();
    final current = getConnections();
    current.removeWhere((c) => c.id == id);
    final str = json.encode(current.map((e) => e.toJson()).toList());
    await _prefs?.setString(_keyConnections, str);
  }
}
