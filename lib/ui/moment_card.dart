import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/models.dart';
import 'common.dart';
import 'profile_avatar.dart';
import 'photo_viewer.dart';

class MomentCard extends StatefulWidget {
  const MomentCard(
      {super.key,
      required this.moment,
      required this.repository,
      required this.onChanged,
      this.demo = false});
  final Moment moment;
  final bool demo;
  final SocialRepository repository;
  final Future<void> Function() onChanged;
  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  late Future<Uint8List> _photo;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _photo = widget.repository.photo(widget.moment.path);
  }

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) notice(context, friendlyError(error));
    } finally {
      // A database delete may succeed even if storage cleanup fails.
      if (mounted) await widget.onChanged();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final date = moment.createdAt.toLocal();
    final dateLabel =
        '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
            child: Row(children: [
              ProfileAvatar(profile: moment.author),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(moment.author.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(dateLabel,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ])),
              if (moment.author.id == widget.repository.userId)
                IconButton(
                    tooltip: 'Xóa ảnh',
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!await confirm(context, 'Xóa khoảnh khắc?',
                                'Ảnh này sẽ biến mất khỏi bảng tin và kỷ niệm.')) {
                              return;
                            }
                            if (!mounted) return;
                            await _change(
                                () => widget.repository.deleteMoment(moment));
                          },
                    icon: const Icon(Icons.delete_outline)),
            ])),
        AspectRatio(
            aspectRatio: 1,
            child: FutureBuilder<Uint8List>(
                future: _photo,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: TextButton.icon(
                            onPressed: () => setState(() =>
                                _photo = widget.repository.photo(moment.path)),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Không tải được ảnh. Thử lại')));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Semantics(
                      label: 'Xem ảnh của ${moment.author.name}',
                      button: true,
                      child: GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PhotoViewer(
                                      moment: moment,
                                      bytes: snapshot.data!,
                                      demo: widget.demo))),
                          child: Image.memory(snapshot.data!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Ảnh không đọc được.')))));
                })),
        if (moment.caption.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child:
                  Text(moment.caption, style: const TextStyle(fontSize: 16))),
        Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 18, 8),
            child: Row(children: [
              IconButton(
                  tooltip: moment.liked ? 'Bỏ thích' : 'Thả tim',
                  onPressed: _busy
                      ? null
                      : () => _change(() => widget.repository.like(moment)),
                  icon: Icon(
                      moment.liked ? Icons.favorite : Icons.favorite_border,
                      color: moment.liked ? Colors.redAccent : null)),
              Text('${moment.likes}'),
              const Spacer(),
              const Icon(Icons.people_outline, size: 16),
              const SizedBox(width: 6),
              Text(widget.demo ? 'Trong phiên thử' : 'Chỉ bạn bè',
                  style: const TextStyle(fontSize: 12)),
            ])),
      ]),
    );
  }
}
