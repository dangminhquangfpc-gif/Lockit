import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class SupabaseRepository implements SocialRepository {
  SupabaseRepository(this.client);
  final SupabaseClient client;

  @override
  String get userId => client.auth.currentUser!.id;

  @override
  Future<Profile> profile() async => Profile.fromJson(
      await client.from('profiles').select().eq('id', userId).single());

  @override
  Future<Profile> updateProfile(
      {required String name,
      required String bio,
      required String emoji,
      required int colorIndex}) async {
    await client.rpc('update_profile', params: {
      'new_name': name.trim(),
      'new_bio': bio.trim(),
      'new_emoji': emoji,
      'new_color': colorIndex,
    });
    return profile();
  }

  @override
  Future<List<Friendship>> friendships() async {
    final rows = await client.from('friendships').select(
        'id, sender_id, recipient_id, status, sender:profiles!friendships_sender_id_fkey(*), recipient:profiles!friendships_recipient_id_fkey(*)');
    return rows
        .map((row) => Friendship(
              id: row['id'] as String,
              senderId: row['sender_id'] as String,
              accepted: row['status'] == 'accepted',
              other: Profile.fromJson(Map<String, dynamic>.from(
                  row[row['sender_id'] == userId ? 'recipient' : 'sender']
                      as Map)),
            ))
        .toList();
  }

  @override
  Future<void> requestFriend(String username) =>
      client.rpc('send_friend_request',
          params: {'target_username': normalizeUsername(username)});

  @override
  Future<void> respond(String id, {required bool accept}) =>
      client.rpc('respond_friend_request',
          params: {'request_id': id, 'approve': accept});

  @override
  Future<void> removeFriend(String id) =>
      client.rpc('remove_friendship', params: {'request_id': id});

  @override
  Future<List<Moment>> moments(
      {bool mine = false, Moment? before, DateTime? onDay}) async {
    var query = client.from('moments').select(
        '*, author:profiles!moments_author_id_fkey(*), reactions(user_id)');
    if (mine) query = query.eq('author_id', userId);
    if (onDay != null) {
      query = query
          .gte('created_at', localDayStart(onDay).toUtc().toIso8601String())
          .lt('created_at', nextLocalDay(onDay).toUtc().toIso8601String());
    }
    if (before != null) {
      // Stable cursor even if multiple posts share a timestamp.
      final timestamp = before.createdAt.toUtc().toIso8601String();
      query = query.or(
          'created_at.lt.$timestamp,and(created_at.eq.$timestamp,id.lt.${before.id})');
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(20);
    return rows.map((row) {
      final reactions = row['reactions'] as List;
      return Moment(
        id: row['id'] as String,
        author:
            Profile.fromJson(Map<String, dynamic>.from(row['author'] as Map)),
        path: row['image_path'] as String,
        caption: row['caption'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        liked: reactions.any((item) => item['user_id'] == userId),
        likes: reactions.length,
      );
    }).toList();
  }

  @override
  Future<Uint8List> photo(String path) =>
      client.storage.from('moments').download(path);

  @override
  Future<void> publish(Uint8List bytes, String caption) async {
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await client.storage.from('moments').uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'));
    try {
      await client.from('moments').insert({
        'author_id': userId,
        'image_path': path,
        'caption': caption.trim(),
      });
    } catch (_) {
      // Best effort cleanup; preserve the original publish error.
      try {
        await client.storage.from('moments').remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> deleteMoment(Moment moment) async {
    // Remove visibility first. Storage policy still permits owner cleanup.
    await client.from('moments').delete().eq('id', moment.id);
    await client.storage.from('moments').remove([moment.path]);
  }

  @override
  Future<void> like(Moment moment) async {
    if (moment.liked) {
      await client
          .from('reactions')
          .delete()
          .eq('moment_id', moment.id)
          .eq('user_id', userId);
    } else {
      await client.from('reactions').upsert({
        'moment_id': moment.id,
        'user_id': userId,
      }, onConflict: 'moment_id,user_id', ignoreDuplicates: true);
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}
