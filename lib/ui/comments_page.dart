import 'package:flutter/material.dart';
import '../data/models.dart';
import '../data/demo_repository.dart';
import 'common.dart';
import 'profile_avatar.dart';

class CommentsPage extends StatefulWidget {
  const CommentsPage(
      {super.key, required this.moment, required this.repository});
  final Moment moment;
  final SocialRepository repository;
  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final List<PhotoComment> _items = [];
  PhotoComment? _reply;
  bool _loading = false, _sending = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.comments(widget.moment.id,
          before: reset || _items.isEmpty ? null : _items.last);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(rows);
        _more = rows.length == 30;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _emoji(String emoji) {
    final selection = _text.selection;
    final start = selection.isValid ? selection.start : _text.text.length;
    final end = selection.isValid ? selection.end : start;
    final value = _text.text.replaceRange(start, end, emoji);
    _text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: start + emoji.length));
  }

  Future<void> _send() async {
    final error = commentError(_text.text);
    if (error != null) {
      notice(context, error);
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.repository
          .sendComment(widget.moment.id, _text.text, replyTo: _reply?.id);
      if (!mounted) return;
      _text.clear();
      setState(() => _reply = null);
      await _load(reset: true);
    } catch (error) {
      if (mounted) notice(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Phản hồi về ảnh'), actions: [
          IconButton(
              tooltip: 'Làm mới phản hồi',
              onPressed: _loading || _sending ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh)),
        ]),
        body: SafeArea(
            child: Column(children: [
          if (widget.repository is DemoRepository)
            Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  const Text('Bản thử • Phản hồi chỉ lưu trong phiên này.'),
                  TextButton(
                      onPressed: _loading || _sending
                          ? null
                          : () {
                              (widget.repository as DemoRepository)
                                  .addSampleComment(widget.moment.id);
                              _load(reset: true);
                            },
                      child: const Text('Thêm phản hồi mẫu từ Linh')),
                ])),
          Expanded(
              child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _items.length) {
                      if (_loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (_error != null) {
                        return TextButton(
                            onPressed: () => _load(reset: _items.isEmpty),
                            child: Text('$_error Thử lại'));
                      }
                      if (_items.isEmpty) {
                        return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'Chưa có phản hồi. Gửi lời đầu tiên nhé!'));
                      }
                      return _more
                          ? TextButton(
                              onPressed: _load,
                              child: const Text('Xem phản hồi trước'))
                          : const SizedBox.shrink();
                    }
                    final item = _items[index];
                    final parents = _items.where((p) => p.id == item.replyTo);
                    final parent = parents.isEmpty ? null : parents.first;
                    final time = item.createdAt.toLocal();
                    return Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    ProfileAvatar(profile: item.author),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(item.author.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Text(
                                        '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 11)),
                                  ]),
                                  if (item.replyTo != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                            parent == null
                                                ? '↪ Trả lời một phản hồi trước đó'
                                                : '↪ ${parent.author.name}: ${parent.body}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.black54))),
                                  Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(item.body)),
                                  TextButton(
                                      onPressed: _sending
                                          ? null
                                          : () {
                                              setState(() => _reply = item);
                                              _focus.requestFocus();
                                            },
                                      child: const Text('Trả lời')),
                                ])));
                  })),
          if (_reply != null)
            ListTile(
                dense: true,
                title: Text('Trả lời ${_reply!.author.name}'),
                subtitle: Text(_reply!.body,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                    tooltip: 'Hủy trả lời',
                    onPressed:
                        _sending ? null : () => setState(() => _reply = null),
                    icon: const Icon(Icons.close))),
          SizedBox(
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final emoji in [
                  '❤️',
                  '😍',
                  '😂',
                  '🥰',
                  '🔥',
                  '👏',
                  '🥺',
                  '✨',
                  '👍',
                  '🎉'
                ])
                  TextButton(
                      onPressed: _sending ? null : () => _emoji(emoji),
                      child: Text(emoji, style: const TextStyle(fontSize: 24))),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                            hintText: 'Viết phản hồi…',
                            helperText: 'Tối đa 500 ký tự',
                            counterText: '',
                            border: OutlineInputBorder()))),
                IconButton(
                    tooltip: 'Gửi phản hồi',
                    onPressed: _sending || _loading ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send)),
              ])),
        ])),
      );
}
