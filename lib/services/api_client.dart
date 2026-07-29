import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown for any non-2xx response from the backend. [message] is the server's
/// `error` field when present, so existing UI that shows `e.toString()` keeps
/// showing something meaningful.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Thin HTTP client for the MediChain backend. Holds the auth token, attaches
/// it to every request, and persists it across launches via SharedPreferences.
///
/// This is the ONLY thing in the app that knows a network exists — every
/// service talks to the backend through this class.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _kAccess = 'mc_access_token';
  static const _kRefresh = 'mc_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  /// Base URL of the backend, from `.env` (`API_BASE_URL`).
  String get baseUrl {
    final url = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String? get accessToken => _accessToken;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// Load persisted tokens at startup.
  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
  }

  /// Persist (or clear, when null) the session tokens.
  Future<void> setTokens(String? access, String? refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    if (access == null) {
      await prefs.remove(_kAccess);
    } else {
      await prefs.setString(_kAccess, access);
    }
    if (refresh == null) {
      await prefs.remove(_kRefresh);
    } else {
      await prefs.setString(_kRefresh, refresh);
    }
  }

  Future<void> clear() => setTokens(null, null);

  // ── Requests ───────────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers(json: false));
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await http.post(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final res = await http.put(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await http.patch(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    final res = await http.delete(
      _uri(path),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  /// Raw bytes (used to download+decrypt records — the backend returns the
  /// decrypted file directly).
  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: _authOnly());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, _errorFrom(res));
    }
    return res.bodyBytes;
  }

  /// Multipart file upload. [fields] are extra form fields (title, category…).
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    required Map<String, String> fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res) as Map<String, dynamic>;
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = query == null
        ? null
        : query.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: (q == null || q.isEmpty) ? null : q);
  }

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Map<String, String> _authOnly() => {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  dynamic _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = res.body;
      }
    }
    if (!ok) {
      final msg = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : 'Request failed (${res.statusCode})';
      throw ApiException(res.statusCode, msg);
    }
    return body;
  }

  String _errorFrom(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) return body['error'].toString();
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }
}
