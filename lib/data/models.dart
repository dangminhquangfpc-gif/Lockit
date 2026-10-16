import 'dart:typed_data';

class Profile {
  const Profile(
      {required this.id,
      required this.username,
      required this.name,
      this.bio = '',
      this.emoji = '',
      this.colorIndex = 0});
  final String id;
  final String username;
  final String name;
  final String bio;
  final String emoji;
  final int colorIndex;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        name: json['display_name'] as String,
        bio: json['bio'] as String? ?? '',
        emoji: json['avatar_emoji'] as String? ?? '',
        colorIndex: json['avatar_color'] as int? ?? 0,
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

class PhotoComment {
  const PhotoComment(
      {required this.id,
      required this.author,
      required this.body,
      required this.createdAt,
      this.replyTo});
  final String id;
  final Profile author;
  final String body;
  final DateTime createdAt;
  final String? replyTo;
}

String? commentError(String value) => value.trim().isEmpty
    ? 'Nhập phản hồi hoặc chọn emoji.'
    : value.trim().runes.length > 500
        ? 'Phản hồi tối đa 500 ký tự.'
        : null;

abstract class SocialRepository {
  String get userId;
  Future<Profile> profile();
  Future<Profile> updateProfile(
      {required String name,
      required String bio,
      required String emoji,
      required int colorIndex});
  Future<List<Friendship>> friendships();
  Future<void> requestFriend(String username);
  Future<void> respond(String id, {required bool accept});
  Future<void> removeFriend(String id);
  Future<List<Moment>> moments(
      {bool mine = false, Moment? before, DateTime? onDay});
  Future<Uint8List> photo(String path);
  Future<void> publish(Uint8List bytes, String caption);
  Future<void> deleteMoment(Moment moment);
  Future<void> like(Moment moment);
  Future<List<PhotoComment>> comments(String momentId, {PhotoComment? before});
  Future<void> sendComment(String momentId, String body, {String? replyTo});
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

const profileEmojiChoices = ['', '☀️', '🌻', '🌿', '🌙', '🐻', '🐱', '🌊', '✨'];

String normalizeUsername(String value) =>
    value.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

String? displayNameError(String? value) {
  final count = (value ?? '').trim().runes.length;
  return count < 1 || count > 40 ? 'Nhập tên từ 1 đến 40 ký tự.' : null;
}

String? bioError(String? value) => (value ?? '').trim().runes.length > 80
    ? 'Giới thiệu tối đa 80 ký tự.'
    : null;

DateTime localDayStart(DateTime day) => DateTime(day.year, day.month, day.day);
DateTime nextLocalDay(DateTime day) =>
    DateTime(day.year, day.month, day.day + 1);
bool sameLocalDay(DateTime first, DateTime second) {
  final a = first.toLocal();
  final b = second.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String dayLabel(DateTime value) {
  final day = value.toLocal();
  final today = DateTime.now();
  if (sameLocalDay(day, today)) return 'Hôm nay';
  if (sameLocalDay(day, DateTime(today.year, today.month, today.day - 1))) {
    return 'Hôm qua';
  }
  return '${day.day}/${day.month}/${day.year}';
}
