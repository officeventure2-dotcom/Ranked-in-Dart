import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to the Cloudflare Worker. Override at build time:
/// flutter run --dart-define=API_BASE=https://your-worker.example.workers.dev
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://rankedapp.officeventure2.workers.dev');

class ApiException implements Exception {
  ApiException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._(this._prefs, this._session);
  final SharedPreferences _prefs;
  String? _session; // the Worker's rk_session cookie value

  static Future<ApiClient> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiClient._(prefs, prefs.getString('rk_session'));
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, Uri.parse('$apiBase$path'));
    req.headers['Content-Type'] = 'application/json';
    if (_session != null) req.headers['Cookie'] = 'rk_session=$_session';
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 20)));
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection and try again.', 0);
    }
    await _saveCookie(res.headers['set-cookie']);
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      // non-JSON body: fall through to the status check
    }
    if (res.statusCode >= 400) {
      throw ApiException((data['error'] as String?) ?? 'Something went wrong (${res.statusCode}).', res.statusCode);
    }
    return data;
  }

  Future<void> _saveCookie(String? header) async {
    if (header == null) return;
    final m = RegExp(r'rk_session=([^;]*)').firstMatch(header);
    if (m == null) return;
    final v = m.group(1)!;
    _session = v.isEmpty ? null : v;
    if (_session == null) {
      await _prefs.remove('rk_session');
    } else {
      await _prefs.setString('rk_session', _session!);
    }
  }
}
