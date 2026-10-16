import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import 'common.dart';
import 'profile_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage(
      {super.key,
      required this.repository,
      required this.profile,
      this.demo = false});
  final SocialRepository repository;
  final Profile profile;
  final bool demo;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late String _emoji;
  late int _color;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _bio = TextEditingController(text: widget.profile.bio);
    _emoji = widget.profile.emoji;
    _color = widget.profile.colorIndex.clamp(0, profileColors.length - 1);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Profile get _preview => Profile(
      id: widget.profile.id,
      username: widget.profile.username,
      name: _name.text.trim(),
      bio: _bio.text,
      emoji: _emoji,
      colorIndex: _color);

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateProfile(
          name: _name.text.trim(),
          bio: _bio.text,
          emoji: _emoji,
          colorIndex: _color);
      if (mounted) {
        notice(
            context,
            widget.demo
                ? 'Đã lưu hồ sơ trong phiên thử.'
                : 'Đã cập nhật hồ sơ.');
        Navigator.pop(context, updated);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ của bạn')),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: ProfileAvatar(profile: _preview, radius: 52)),
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                                child: SelectableText(
                                    '@${widget.profile.username}',
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                tooltip: 'Sao chép tên người dùng',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(
                                      text: '@${widget.profile.username}'));
                                  if (mounted) {
                                    notice(
                                        context, 'Đã sao chép tên người dùng.');
                                  }
                                }),
                          ]),
                      const Text('Chọn một biểu tượng cho riêng mình',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final emoji in profileEmojiChoices)
                              ChoiceChip(
                                  label:
                                      Text(emoji.isEmpty ? 'Chữ cái' : emoji),
                                  selected: emoji == _emoji,
                                  onSelected: _saving
                                      ? null
                                      : (_) => setState(() => _emoji = emoji)),
                          ]),
                      const SizedBox(height: 16),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (var i = 0; i < profileColors.length; i++)
                              Semantics(
                                  label: 'Màu đại diện ${i + 1}',
                                  selected: _color == i,
                                  button: true,
                                  child: InkWell(
                                      onTap: _saving
                                          ? null
                                          : () => setState(() => _color = i),
                                      borderRadius: BorderRadius.circular(24),
                                      child: CircleAvatar(
                                          backgroundColor: profileColors[i],
                                          child: _color == i
                                              ? const Icon(Icons.check,
                                                  color: Color(0xFF193B32))
                                              : null))),
                          ]),
                      const SizedBox(height: 28),
                      TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          maxLength: 40,
                          validator: displayNameError,
                          onChanged: (_) => setState(() {}),
                          decoration:
                              const InputDecoration(labelText: 'Tên hiển thị')),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _bio,
                          enabled: !_saving,
                          maxLength: 80,
                          maxLines: 3,
                          validator: bioError,
                          decoration: const InputDecoration(
                              labelText: 'Đôi lời về bạn',
                              hintText:
                                  'Một điều nhỏ khiến bạn vui mỗi ngày…')),
                      const SizedBox(height: 12),
                      Text(
                          widget.demo
                              ? 'Hồ sơ chỉ được lưu trong phiên trải nghiệm này.'
                              : 'Tên, biểu tượng và giới thiệu hiển thị với người dùng trong ứng dụng.',
                          style: const TextStyle(color: Colors.black54),
                          textAlign: TextAlign.center),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_error!)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.check),
                          label: Text(_saving ? 'Đang lưu…' : 'Lưu hồ sơ')),
                    ])),
          )),
        )),
      ));
}
