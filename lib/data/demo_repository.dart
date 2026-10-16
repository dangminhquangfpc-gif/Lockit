import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

/// Explicitly offline: no network, persistence, or real friend accounts.
class DemoRepository implements SocialRepository {
  DemoRepository({this.onSignOut});
  final void Function()? onSignOut;
  static const me = Profile(id: 'demo-me', username: 'ban_demo', name: 'Bạn');
  Profile _profile = me;
  static const linh =
      Profile(id: 'demo-linh', username: 'linh_demo', name: 'Linh (mẫu)');
  static const minh =
      Profile(id: 'demo-minh', username: 'minh_demo', name: 'Minh (mẫu)');
  final List<Friendship> _friends = [
    const Friendship(
        id: 'demo-incoming',
        senderId: 'demo-linh',
        accepted: false,
        other: linh),
  ];
  final List<Moment> _posts = [];
  final Map<String, Uint8List> _photos = {};
  int _sequence = 0;

  @override
  String get userId => me.id;
  @override
  Future<Profile> profile() async => _profile;
  @override
  Future<Profile> updateProfile(
      {required String name,
      required String bio,
      required String emoji,
      required int colorIndex}) async {
    if (displayNameError(name) != null ||
        bioError(bio) != null ||
        !profileEmojiChoices.contains(emoji) ||
        colorIndex < 0 ||
        colorIndex > 5) {
      throw ArgumentError('Invalid profile');
    }
    _profile = Profile(
        id: me.id,
        username: me.username,
        name: name.trim(),
        bio: bio.trim(),
        emoji: emoji,
        colorIndex: colorIndex);
    return _profile;
  }

  @override
  Future<List<Friendship>> friendships() async => List.of(_friends);
  @override
  Future<void> requestFriend(String username) async {
    final value = normalizeUsername(username);
    if (value == me.username) {
      throw const PostgrestException(message: 'cannot_add_self');
    }
    final other = value == linh.username
        ? linh
        : value == minh.username
            ? minh
            : null;
    if (other == null) {
      throw const PostgrestException(message: 'user_not_found');
    }
    if (_friends.any((item) => item.other.id == other.id)) {
      throw const PostgrestException(message: 'request_exists');
    }
    _friends.add(Friendship(
        id: 'request-${++_sequence}',
        senderId: me.id,
        accepted: false,
        other: other));
  }

  @override
  Future<void> respond(String id, {required bool accept}) async {
    final index =
        _friends.indexWhere((item) => item.id == id && item.incoming(me.id));
    if (index == -1) {
      throw const PostgrestException(message: 'request_not_found');
    }
    final request = _friends.removeAt(index);
    if (accept) {
      _friends.add(Friendship(
          id: request.id,
          senderId: request.senderId,
          accepted: true,
          other: request.other));
    }
  }

  @override
  Future<void> removeFriend(String id) async {
    _friends.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<Moment>> moments(
      {bool mine = false, Moment? before, DateTime? onDay}) async {
    var posts = _posts.toList()
      ..sort((a, b) {
        final date = b.createdAt.compareTo(a.createdAt);
        return date == 0 ? b.id.compareTo(a.id) : date;
      });
    if (before != null) {
      posts = posts
          .where((item) =>
              item.createdAt.isBefore(before.createdAt) ||
              (item.createdAt == before.createdAt &&
                  item.id.compareTo(before.id) < 0))
          .toList();
    }
    if (onDay != null) {
      final start = localDayStart(onDay).toUtc();
      final end = nextLocalDay(onDay).toUtc();
      posts = posts
          .where((item) =>
              !item.createdAt.isBefore(start) && item.createdAt.isBefore(end))
          .toList();
    }
    return posts
        .take(20)
        .map((item) => Moment(
            id: item.id,
            author: _profile,
            path: item.path,
            caption: item.caption,
            createdAt: item.createdAt,
            liked: item.liked,
            likes: item.likes))
        .toList();
  }

  @override
  Future<Uint8List> photo(String path) async {
    final bytes = _photos[path];
    if (bytes == null) throw StateError('Ảnh thử không còn tồn tại.');
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> publish(Uint8List bytes, String caption) async {
    final id = 'demo-${++_sequence}';
    _photos[id] = Uint8List.fromList(bytes);
    _posts.add(Moment(
        id: id,
        author: _profile,
        path: id,
        caption: caption.trim(),
        createdAt: DateTime.now().toUtc(),
        liked: false,
        likes: 0));
  }

  @override
  Future<void> deleteMoment(Moment moment) async {
    _posts.removeWhere((item) => item.id == moment.id);
    _photos.remove(moment.path);
  }

  @override
  Future<void> like(Moment moment) async {
    final index = _posts.indexWhere((item) => item.id == moment.id);
    if (index == -1) return;
    final current = _posts[index];
    _posts[index] = Moment(
        id: current.id,
        author: current.author,
        path: current.path,
        caption: current.caption,
        createdAt: current.createdAt,
        liked: !current.liked,
        likes: current.liked ? 0 : 1);
  }

  @override
  Future<void> signOut() async {
    _posts.clear();
    _photos.clear();
    _friends.clear();
    onSignOut?.call();
  }
}
