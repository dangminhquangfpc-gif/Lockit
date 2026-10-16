import 'dart:typed_data';

class Profile {
  const Profile({required this.id, required this.username, required this.name});
  final String id;
  final String username;
  final String name;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        name: json['display_name'] as String,
      );
}

class Friendship {
  const Friendship({
    required this.id,
    required this.senderId,
    required this.accepted,
    required this.other,
  });
  final String id;
  final String senderId;
  final bool accepted;
  final Profile other;
  bool incoming(String userId) => !accepted && senderId != userId;
}

class Moment {
  const Moment({
    required this.id,
    required this.author,
    required this.path,
    required this.caption,
    required this.createdAt,
    required this.liked,
    required this.likes,
  });
  final String id;
  final Profile author;
  final String path;
  final String caption;
  final DateTime createdAt;
  final bool liked;
  final int likes;
}

abstract class SocialRepository {
  String get userId;
  Future<Profile> profile();
  Future<List<Friendship>> friendships();
  Future<void> requestFriend(String username);
  Future<void> respond(String id, {required bool accept});
  Future<void> removeFriend(String id);
  Future<List<Moment>> moments({bool mine = false, Moment? before});
  Future<Uint8List> photo(String path);
  Future<void> publish(Uint8List bytes, String caption);
  Future<void> deleteMoment(Moment moment);
  Future<void> like(Moment moment);
  Future<void> signOut();
}

String? usernameError(String? value) {
  if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(value?.trim() ?? '')) {
    return 'Dùng 3–24 chữ thường, số hoặc dấu gạch dưới.';
  }
  return null;
}

String? passwordError(String? value) =>
    (value?.length ?? 0) < 8 ? 'Mật khẩu cần ít nhất 8 ký tự.' : null;
