import 'package:flutter/material.dart';
import '../data/demo_repository.dart';
import 'social_home.dart';

class DemoSession extends StatefulWidget {
  const DemoSession({super.key});
  @override
  State<DemoSession> createState() => _DemoSessionState();
}

class _DemoSessionState extends State<DemoSession> {
  late DemoRepository _repository;
  bool _active = true;
  @override
  void initState() {
    super.initState();
    _newSession();
  }

  void _newSession() {
    _repository = DemoRepository(onSignOut: () {
      if (mounted) setState(() => _active = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return Scaffold(
          body: Center(
              child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline,
              size: 64, color: Color(0xFF285449)),
          const SizedBox(height: 16),
          const Text('Phiên trải nghiệm đã kết thúc',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Ảnh thử và bạn bè mẫu đã được xóa khỏi phiên này.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: () => setState(() {
                    _newSession();
                    _active = true;
                  }),
              child: const Text('Trải nghiệm lại')),
        ]),
      )));
    }
    return Scaffold(
        body: SafeArea(
            bottom: false,
            child: Column(children: [
              Container(
                  width: double.infinity,
                  color: const Color(0xFFF4C95D),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Text(
                      'BẢN TRẢI NGHIỆM • Bạn bè mẫu\nẢnh chỉ lưu trong phiên thử, không gửi cho người khác.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF162E28)))),
              Expanded(
                  child: SocialHome(
                      key: ObjectKey(_repository),
                      repository: _repository,
                      demo: true)),
            ])));
  }
}
