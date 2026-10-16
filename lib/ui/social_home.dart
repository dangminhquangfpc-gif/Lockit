import 'package:flutter/material.dart';
import '../data/models.dart';
import 'camera_page.dart';
import 'common.dart';
import 'friends_page.dart';
import 'moment_card.dart';

class SocialHome extends StatefulWidget {
  const SocialHome({super.key, required this.repository, this.demo = false});
  final SocialRepository repository;
  final bool demo;
  @override
  State<SocialHome> createState() => _SocialHomeState();
}

class _SocialHomeState extends State<SocialHome> with WidgetsBindingObserver {
  int _tab = 0;
  int _version = 0;
  bool _signingOut = false;
  late Future<Profile> _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profile = widget.repository.profile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() => _version++);
  }

  Future<void> _camera() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          CameraPage(repository: widget.repository, localOnly: widget.demo),
    ));
    if (mounted && sent == true) {
      setState(() {
        _tab = 0;
        _version++;
      });
    }
  }

  Future<void> _logout() async {
    setState(() => _signingOut = true);
    try {
      await widget.repository.signOut();
    } catch (error) {
      if (mounted) notice(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: const Text('lockit ✦',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1)),
          actions: [
            IconButton(
                tooltip: 'Đăng xuất',
                onPressed: _signingOut ? null : _logout,
                icon: const Icon(Icons.logout_rounded))
          ],
        ),
        body: FutureBuilder<Profile>(
            future: _profile,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const EmptyMessage(
                      'Chưa tải được hồ sơ', 'Kiểm tra kết nối rồi thử lại.'),
                  FilledButton(
                      onPressed: () => setState(
                          () => _profile = widget.repository.profile()),
                      child: const Text('Thử lại')),
                ]));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_tab == 1) {
                return FriendsPage(
                    key: ValueKey('friends-$_version'),
                    repository: widget.repository,
                    me: snapshot.data!);
              }
              return MomentFeed(
                  key: ValueKey('$_tab-$_version'),
                  repository: widget.repository,
                  mine: _tab == 2,
                  demo: widget.demo,
                  name: snapshot.data!.name,
                  onCapture: _camera);
            }),
        floatingActionButton: _tab == 1
            ? null
            : FloatingActionButton.extended(
                backgroundColor: const Color(0xFFF4C95D),
                foregroundColor: const Color(0xFF193B32),
                onPressed: _camera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Chụp khoảnh khắc')),
        bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() {
                  _tab = value;
                  _version++;
                }),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Mỗi ngày'),
              NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Bạn bè'),
              NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Kỷ niệm'),
            ]),
      );
}

class MomentFeed extends StatefulWidget {
  const MomentFeed(
      {super.key,
      required this.repository,
      required this.mine,
      required this.name,
      required this.onCapture,
      this.demo = false});
  final SocialRepository repository;
  final bool mine;
  final bool demo;
  final String name;
  final VoidCallback onCapture;
  @override
  State<MomentFeed> createState() => _MomentFeedState();
}

class _MomentFeedState extends State<MomentFeed> {
  List<Moment> _moments = [];
  bool _loading = true;
  bool _more = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.moments(
          mine: widget.mine,
          before: reset || _moments.isEmpty ? null : _moments.last);
      if (mounted && generation == _generation) {
        setState(() {
          _moments = reset ? rows : [..._moments, ...rows];
          _more = rows.length == 20;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = friendlyError(error);
          if (reset) {
            _moments =
                []; // Do not leave stale private photos on refresh errors.
          }
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                  widget.mine ? 'Những ngày đáng nhớ' : 'Chào ${widget.name} ☀',
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8)),
              const SizedBox(height: 8),
              Text(
                  widget.mine
                      ? 'Một cuốn nhật ký bằng những bức ảnh của bạn.'
                      : 'Một khoảnh khắc nhỏ. Một ngày gần nhau hơn.',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, textAlign: TextAlign.center),
                TextButton(
                    onPressed: _loading ? null : () => _load(reset: true),
                    child: const Text('Thử lại')),
              ],
              if (!_loading && _error == null && _moments.isEmpty) ...[
                EmptyMessage(
                    widget.mine
                        ? 'Ngày đầu tiên của cuốn nhật ký'
                        : 'Bảng tin đang chờ bạn',
                    widget.mine
                        ? 'Chụp một bức ảnh để lưu lại hôm nay.'
                        : 'Kết bạn và chia sẻ một bức ảnh. Khoảnh khắc của hai bạn sẽ xuất hiện ở đây.',
                    icon: Icons.wb_sunny_outlined),
                OutlinedButton(
                    onPressed: widget.onCapture,
                    child: const Text('Chụp ảnh đầu tiên')),
              ],
              for (final moment in _moments)
                MomentCard(
                    key: ValueKey(moment.id),
                    demo: widget.demo,
                    moment: moment,
                    repository: widget.repository,
                    onChanged: () => _load(reset: true)),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
              if (!_loading && _more && _moments.isNotEmpty)
                TextButton(
                    onPressed: () => _load(),
                    child: const Text('Xem những ngày trước')),
            ]),
      );
}
