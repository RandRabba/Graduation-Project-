import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// DMS backend (backend/ folder). Override per build:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.12:8000`.
/// The default reaches a backend on your computer from the Android emulator.
const kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

/// A failed request. [status] is 0 when the server couldn't be reached.
class ApiException implements Exception {
  const ApiException(this.message, {this.status = 0});
  final String message;
  final int status;

  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status): $message';
}

/// Thin JSON client. Every call carries the session token once signed in.
class Api {
  Api({http.Client? client, String baseUrl = kApiBaseUrl})
    : _http = client ?? http.Client(),
      _base = Uri.parse(baseUrl);

  final http.Client _http;
  final Uri _base;
  String? token;

  /// Called when the server rejects the token (expired or revoked).
  VoidCallback? onUnauthorized;

  Future<dynamic> get(String path, [Map<String, Object?> query = const {}]) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body ?? const {});
  Future<dynamic> put(String path, Object body) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, Object body) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Object? body,
  }) async {
    final params = {
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    final uri = _base.replace(
      path: '${_base.path}$path',
      queryParameters: params.isEmpty ? null : params,
    );
    final req = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 20)),
      );
    } catch (_) {
      throw const ApiException('Network error');
    }
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      if (res.statusCode == 401 && token != null) onUnauthorized?.call();
      throw ApiException(_detail(data), status: res.statusCode);
    }
    return data;
  }

  /// FastAPI sends `{"detail": "..."}` or, for validation, a list of `{msg}`.
  static String _detail(Object? data) {
    final d = data is Map ? data['detail'] : null;
    if (d is String) return d;
    if (d is List) {
      return d
          .map((e) => '${e is Map ? e['msg'] : e}')
          .map((m) => m.replaceFirst('Value error, ', ''))
          .join('\n');
    }
    return 'Request failed';
  }
}

/// Where the session token is kept between launches.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

/// Keychain / Android Keystore-backed storage.
class SecureTokenStore implements TokenStore {
  static const _key = 'dms_session_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? token) => token == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: token);
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.value]);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? token) async => value = token;
}
