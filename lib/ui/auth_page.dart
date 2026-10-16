import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models.dart';
import 'common.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;
  String? _message;

  @override
  void dispose() {
    for (final controller in [_email, _password, _username, _name]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        final response = await widget.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {
            'username': _username.text.trim(),
            'display_name': _name.text.trim()
          },
        );
        if (mounted && response.session == null) {
          setState(() => _message =
              'Kiểm tra hộp thư để xác nhận email, sau đó đăng nhập.');
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: AutofillGroup(
                child: Form(
                    key: _form,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.camera_rounded,
                              size: 64, color: Color(0xFF285449)),
                          const SizedBox(height: 16),
                          const Text('Lockit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -2)),
                          const SizedBox(height: 8),
                          const Text('Một chút mỗi ngày, gần nhau hơn.',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 36),
                          Text(
                              _register
                                  ? 'Bắt đầu câu chuyện của bạn'
                                  : 'Vui vì bạn quay lại',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          if (_register) ...[
                            TextFormField(
                                controller: _name,
                                maxLength: 40,
                                decoration: const InputDecoration(
                                    labelText: 'Tên hiển thị'),
                                validator: (value) =>
                                    (value?.trim().isEmpty ?? true)
                                        ? 'Nhập tên của bạn.'
                                        : null),
                            const SizedBox(height: 12),
                            TextFormField(
                                controller: _username,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                    labelText: 'Tên người dùng',
                                    prefixText: '@'),
                                validator: usernameError),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              decoration:
                                  const InputDecoration(labelText: 'Email'),
                              validator: (value) =>
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(value?.trim() ?? '')
                                      ? null
                                      : 'Nhập email hợp lệ.'),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _password,
                              obscureText: _hide,
                              autofillHints: [
                                _register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password
                              ],
                              decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  suffixIcon: IconButton(
                                      tooltip: _hide
                                          ? 'Hiện mật khẩu'
                                          : 'Ẩn mật khẩu',
                                      onPressed: () =>
                                          setState(() => _hide = !_hide),
                                      icon: Icon(_hide
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined))),
                              validator: passwordError,
                              onFieldSubmitted: (_) {
                                if (!_busy) _submit();
                              }),
                          if (_message != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(_message!,
                                    key: const Key('auth-message'))),
                          const SizedBox(height: 24),
                          FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(_busy
                                  ? 'Đang xử lý…'
                                  : _register
                                      ? 'Tạo tài khoản'
                                      : 'Đăng nhập')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _register = !_register;
                                        _message = null;
                                        _form.currentState?.reset();
                                      }),
                              child: Text(_register
                                  ? 'Đã có tài khoản? Đăng nhập'
                                  : 'Chưa có tài khoản? Đăng ký')),
                          const SizedBox(height: 24),
                          const Text(
                              'Ảnh chỉ hiển thị với bạn và những người đã được bạn chấp nhận kết bạn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54)),
                        ])),
              )),
        ))),
      );
}
