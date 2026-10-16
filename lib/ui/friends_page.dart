import 'package:flutter/material.dart';
import '../data/models.dart';
import 'common.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.repository, required this.me});
  final SocialRepository repository;
  final Profile me;
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _username = TextEditingController();
  final _form = GlobalKey<FormState>();
  late Future<List<Friendship>> _future;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.friendships();
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.repository.friendships();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {/* Displayed by FutureBuilder. */}
  }

  Future<void> _action(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        notice(context, success);
        await _refresh();
      }
    } catch (error) {
      if (mounted) notice(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, List<Friendship> rows) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold))),
        for (final row in rows)
          Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    CircleAvatar(
                        child: Text(row.other.name.isEmpty
                            ? '?'
                            : row.other.name.substring(0, 1).toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(row.other.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('@${row.other.username}'),
                        ])),
                  ]),
                  const SizedBox(height: 8),
                  if (row.incoming(widget.me.id))
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => _action(
                                  () => widget.repository
                                      .respond(row.id, accept: false),
                                  'Đã từ chối lời mời.'),
                          child: const Text('Từ chối')),
                      FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _action(
                                  () => widget.repository
                                      .respond(row.id, accept: true),
                                  'Hai bạn đã kết bạn!'),
                          child: const Text('Chấp nhận')),
                    ])
                  else
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (row.accepted &&
                                        !await confirm(context, 'Hủy kết bạn?',
                                            'Hai bạn sẽ không còn xem được ảnh của nhau.')) {
                                      return;
                                    }
                                    if (!mounted) return;
                                    await _action(
                                        () => widget.repository
                                            .removeFriend(row.id),
                                        row.accepted
                                            ? 'Đã hủy kết bạn.'
                                            : 'Đã thu hồi lời mời.');
                                  },
                            child: Text(row.accepted
                                ? 'Hủy kết bạn'
                                : 'Thu hồi lời mời'))),
                ])),
          ),
      ]);

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const Text('Gần nhau hơn',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Chia sẻ tên người dùng để bạn bè tìm thấy bạn.'),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: SelectableText('@${widget.me.username}',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary))),
              Form(
                  key: _form,
                  child: TextFormField(
                      controller: _username,
                      autocorrect: false,
                      validator: usernameError,
                      decoration: const InputDecoration(
                          labelText: 'Tên người dùng của bạn bè',
                          prefixText: '@'))),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          if (!_form.currentState!.validate()) return;
                          FocusScope.of(context).unfocus();
                          _action(
                              () => widget.repository
                                  .requestFriend(_username.text),
                              'Đã gửi lời mời kết bạn.');
                        },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(_busy ? 'Đang xử lý…' : 'Gửi lời mời')),
              FutureBuilder<List<Friendship>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return Column(children: [
                        const EmptyMessage('Chưa tải được bạn bè',
                            'Kiểm tra kết nối và thử lại.'),
                        TextButton(
                            onPressed: _refresh, child: const Text('Thử lại')),
                      ]);
                    }
                    final rows = snapshot.data!;
                    if (rows.isEmpty) {
                      return const EmptyMessage('Bắt đầu với một người bạn',
                          'Gửi lời mời bằng tên người dùng. Ảnh chỉ được chia sẻ khi người kia chấp nhận.',
                          icon: Icons.people_outline);
                    }
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(
                              'Lời mời đến',
                              rows
                                  .where((row) => row.incoming(widget.me.id))
                                  .toList()),
                          _section('Bạn bè',
                              rows.where((row) => row.accepted).toList()),
                          _section(
                              'Đang chờ phản hồi',
                              rows
                                  .where((row) =>
                                      !row.accepted &&
                                      !row.incoming(widget.me.id))
                                  .toList()),
                        ]);
                  }),
            ]),
      );
}
