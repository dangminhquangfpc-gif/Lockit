import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

/// Explicitly offline: no network, persistence, or real friend accounts.
class DemoRepository implements SocialRepository {
  DemoRepository({this.onSignOut});
  final void Function()? onSignOut;
  static const me = Profile(id: 'demo-me', username: 'ban_demo', name: 'Bạn');
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
  Future<Profile> profile() async => me;
  @override
  Future<List<Friendship>> friendships() async => List.of(_friends);
  @override
  Future<void> requestFriend(String username) async {
    final value = username.trim();
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
  Future<List<Moment>> moments({bool mine = false, Moment? before}) async {
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
    return posts.take(20).toList();
  }

  @override
  Future<Uint8List> photo(String path) async =>
      Uint8List.fromList(_photos[path]!);
  @override
  Future<void> publish(Uint8List bytes, String caption) async {
    final id = 'demo-${++_sequence}';
    _photos[id] = Uint8List.fromList(bytes);
    _posts.add(Moment(
        id: id,
        author: me,
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
