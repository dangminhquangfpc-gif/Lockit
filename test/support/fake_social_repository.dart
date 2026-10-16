import 'dart:typed_data';
import 'package:lockit/data/models.dart';

const me = Profile(id: 'me', username: 'minh', name: 'Minh');
const friend = Profile(id: 'friend', username: 'linh', name: 'Linh');

class FakeRepository implements SocialRepository {
  List<Friendship> connections = [];
  List<Moment> posts = [];
  final List<String> requests = [];
  final List<String> accepted = [];
  final List<String> removed = [];
  bool offline = false;
  Profile currentProfile = me;
  DateTime? requestedDay;
  bool requestedMine = false;
  int profileWrites = 0;
  bool loggedOut = false;
  @override
  String get userId => me.id;
  @override
  Future<Profile> profile() async => currentProfile;
  @override
  Future<Profile> updateProfile(
      {required String name,
      required String bio,
      required String emoji,
      required int colorIndex}) async {
    if (offline) throw Exception('offline');
    profileWrites++;
    currentProfile = Profile(
        id: me.id,
        username: me.username,
        name: name.trim(),
        bio: bio.trim(),
        emoji: emoji,
        colorIndex: colorIndex);
    return currentProfile;
  }

  @override
  Future<List<Friendship>> friendships() async => connections;
  @override
  Future<void> requestFriend(String username) async {
    if (offline) throw Exception('offline');
    requests.add(username);
  }

  @override
  Future<void> respond(String id, {required bool accept}) async {
    if (accept) accepted.add(id);
    connections = connections.where((row) => row.id != id).toList();
  }

  @override
  Future<void> removeFriend(String id) async {
    removed.add(id);
    connections = connections.where((row) => row.id != id).toList();
  }

  @override
  Future<List<Moment>> moments(
      {bool mine = false, Moment? before, DateTime? onDay}) async {
    requestedDay = onDay;
    requestedMine = mine;
    if (offline) throw Exception('offline');
    return posts.where((post) => !mine || post.author.id == me.id).toList();
  }

  @override
  Future<Uint8List> photo(String path) async => Uint8List(0);
  @override
  Future<void> publish(Uint8List bytes, String caption) async {}
  @override
  Future<void> deleteMoment(Moment moment) async => posts.remove(moment);
  @override
  Future<void> like(Moment moment) async {}
  @override
  Future<void> signOut() async {
    loggedOut = true;
  }

  final List<PhotoComment> feedback = [];
  @override
  Future<List<PhotoComment>> comments(String momentId,
      {PhotoComment? before}) async {
    if (offline) throw StateError('offline');
    return before == null ? List.of(feedback.reversed) : [];
  }

  @override
  Future<void> sendComment(String momentId, String body,
      {String? replyTo}) async {
    if (offline) throw StateError('offline');
    feedback.add(PhotoComment(
        id: '${feedback.length}',
        author: currentProfile,
        body: body.trim(),
        createdAt: DateTime.now(),
        replyTo: replyTo));
  }
}
