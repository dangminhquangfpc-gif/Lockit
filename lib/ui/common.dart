import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login')) {
      return 'Email hoặc mật khẩu chưa đúng.';
    }
    if (message.contains('email not confirmed')) {
      return 'Hãy xác nhận email trước khi đăng nhập.';
    }
    if (message.contains('already registered')) {
      return 'Email này đã được đăng ký.';
    }
    if (message.contains('database error saving new user')) {
      return 'Chưa tạo được hồ sơ. Hãy thử tên người dùng khác.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Bạn thao tác hơi nhanh. Hãy thử lại sau ít phút.';
    }
    return 'Không thể đăng nhập hoặc đăng ký. Kiểm tra thông tin và thử lại.';
  }
  if (error is PostgrestException) {
    switch (error.message) {
      case 'profile_not_found':
        return 'Chưa tìm thấy hồ sơ. Hãy tải lại và thử lại.';
      case 'user_not_found':
        return 'Không tìm thấy tên người dùng này.';
      case 'cannot_add_self':
        return 'Bạn không thể kết bạn với chính mình.';
      case 'request_exists':
        return 'Đã có lời mời hoặc hai bạn đã kết bạn.';
      case 'request_not_found':
        return 'Lời mời không còn tồn tại. Hãy tải lại.';
    }
  }
  return 'Không thể hoàn tất. Kiểm tra kết nối và thử lại.';
}

void notice(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage(this.title, this.subtitle,
      {super.key, this.icon = Icons.favorite_border});
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(subtitle, textAlign: TextAlign.center),
        ]),
      );
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Giữ lại')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Xác nhận')),
              ],
            )) ??
    false;
