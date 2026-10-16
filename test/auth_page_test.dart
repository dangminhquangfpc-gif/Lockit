import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockit/ui/auth_page.dart';
import 'support/supabase_fixture.dart';

void main() {
  testWidgets('invalid login fields do not make a network request',
      (tester) async {
    final fixture = SupabaseFixture((_) => jsonResponse({}));
    addTearDown(fixture.dispose);
    await tester
        .pumpWidget(MaterialApp(home: AuthPage(client: fixture.client)));
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
    expect(find.text('Mật khẩu cần ít nhất 8 ký tự.'), findsOneWidget);
    expect(fixture.requests, isEmpty);
  });

  testWidgets(
      'registration sends profile metadata and explains email confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = SupabaseFixture((_) => jsonResponse({'user': testUser}));
    addTearDown(fixture.dispose);
    await tester
        .pumpWidget(MaterialApp(home: AuthPage(client: fixture.client)));
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  Minh  ');
    await tester.enterText(fields.at(1), 'minh_123');
    await tester.enterText(fields.at(2), 'minh@example.test');
    await tester.enterText(fields.at(3), 'test-password');
    await tester.ensureVisible(find.text('Tạo tài khoản'));
    await tester.tap(find.text('Tạo tài khoản'));
    await tester.pumpAndSettle();
    expect(fixture.requests, hasLength(1));
    expect(fixture.requests.single.url.path, '/auth/v1/signup');
    final body = jsonDecode(fixture.requests.single.body) as Map;
    expect(body['email'], 'minh@example.test');
    expect(body['code_challenge_method'], 's256');
    expect(body['code_challenge'], isNotEmpty);
    expect(body['data'], {'username': 'minh_123', 'display_name': 'Minh'});
    expect(find.text('Kiểm tra hộp thư để xác nhận email, sau đó đăng nhập.'),
        findsOneWidget);
  });

  testWidgets('incorrect password shows a useful error and lets the user retry',
      (tester) async {
    final fixture = SupabaseFixture(
        (_) => jsonResponse({
              'error': 'invalid_grant',
              'error_description': 'Invalid login credentials',
            }, status: 400),
        autoLogin: false);
    addTearDown(fixture.dispose);
    await tester
        .pumpWidget(MaterialApp(home: AuthPage(client: fixture.client)));
    await tester.enterText(
        find.byType(TextFormField).at(0), 'minh@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc mật khẩu chưa đúng.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(fixture.requests.single.url.path, '/auth/v1/token');
  });
}
