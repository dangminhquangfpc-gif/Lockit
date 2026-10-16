import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

const testUserId = '00000000-0000-0000-0000-000000000001';
const testUser = <String, dynamic>{
  'id': testUserId,
  'aud': 'authenticated',
  'email': 'minh@example.test',
  'created_at': '2026-10-16T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': {'username': 'minh', 'display_name': 'Minh'},
};

http.Response jsonResponse(Object? value, {int status = 200}) =>
    http.Response(value == null ? '' : jsonEncode(value), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

class SupabaseFixture {
  SupabaseFixture(FutureOr<http.Response> Function(http.Request) handle,
      {bool autoLogin = true}) {
    client = SupabaseClient('https://lockit.example.test', 'public-test-key',
        isolate: TestJsonIsolate(),
        authOptions: AuthClientOptions(
            autoRefreshToken: false, pkceAsyncStorage: TestAuthStorage()),
        storageOptions: const StorageClientOptions(retryAttempts: 0),
        httpClient: MockClient((request) async {
      requests.add(request);
      if (autoLogin && request.url.path == '/auth/v1/token') {
        final segment = base64Url
            .encode(utf8.encode(jsonEncode({
              'sub': testUserId,
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            })))
            .replaceAll('=', '');
        return jsonResponse({
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$segment.test-signature',
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': testUser,
        });
      }
      final response = await handle(request);
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers,
          request: request,
          reasonPhrase: response.reasonPhrase);
    }));
  }
  late final SupabaseClient client;
  final List<http.Request> requests = [];
  Future<void> login() async {
    await client.auth.signInWithPassword(
        email: 'minh@example.test', password: 'test-password');
    requests.clear();
  }

  Future<void> dispose() => client.dispose();
}

// Keep widget tests deterministic without spawning real threads in FakeAsync.
class TestJsonIsolate extends YAJsonIsolate {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<dynamic> decode(String json) async => jsonDecode(json);
  @override
  Future<String> encode(dynamic value) async => jsonEncode(value);
}

class TestAuthStorage extends GotrueAsyncStorage {
  final Map<String, String> _values = {};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
