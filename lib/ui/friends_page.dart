import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import 'common.dart';
import 'profile_avatar.dart';

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
  String _search = '';
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

  Widget _section(String title, List<Friendship> rows) => rows.isEmpty
      ? const SizedBox.shrink()
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Text('$title (${rows.length})',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold))),
          for (final row in rows)
            Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      ProfileAvatar(profile: row.other),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(row.other.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('@${row.other.username}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (row.other.bio.isNotEmpty)
                              Text(row.other.bio,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 12)),
                          ])),
                    ]),
                    const SizedBox(height: 8),
                    if (row.incoming(widget.me.id))
                      Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
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
                                          !await confirm(
                                              context,
                                              'Hủy kết bạn?',
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
                  child: Row(children: [
                    Expanded(
                        child: SelectableText('@${widget.me.username}',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary))),
                    IconButton(
                        tooltip: 'Sao chép tên người dùng',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: '@${widget.me.username}'));
                          if (mounted) {
                            notice(context, 'Đã sao chép tên người dùng.');
                          }
                        }),
                  ])),
              Form(
                  key: _form,
                  child: TextFormField(
                      controller: _username,
                      enabled: !_busy,
                      autocorrect: false,
                      validator: (value) =>
                          usernameError(normalizeUsername(value ?? '')),
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
                          _action(() async {
                            await widget.repository.requestFriend(
                                normalizeUsername(_username.text));
                            if (mounted) _username.clear();
                          }, 'Đã gửi lời mời kết bạn.');
                        },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(_busy ? 'Đang xử lý…' : 'Gửi lời mời')),
              const SizedBox(height: 24),
              TextField(
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                      labelText: 'Tìm trong danh sách bạn bè',
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tên hoặc @tên người dùng')),
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
                    final allRows = snapshot.data!;
                    final query = _search.replaceFirst(RegExp(r'^@'), '');
                    final rows = allRows
                        .where((row) =>
                            row.other.name.toLowerCase().contains(query) ||
                            row.other.username.contains(query))
                        .toList()
                      ..sort((a, b) => a.other.name
                          .toLowerCase()
                          .compareTo(b.other.name.toLowerCase()));
                    if (allRows.isNotEmpty && rows.isEmpty) {
                      return const EmptyMessage('Chưa tìm thấy người bạn này',
                          'Thử tìm bằng tên hoặc tên người dùng khác.',
                          icon: Icons.search);
                    }
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
