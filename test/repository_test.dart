import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lockit/data/models.dart';
import 'package:lockit/data/supabase_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/supabase_fixture.dart';

const testProfile = {
  'id': testUserId,
  'username': 'minh',
  'display_name': 'Minh'
};
Map<String, dynamic> postJson() => {
      'id': '00000000-0000-0000-0000-000000000004',
      'author': testProfile,
      'image_path': '$testUserId/today.jpg',
      'caption': 'Hôm nay',
      'created_at': '2026-10-16T05:00:00Z',
      'reactions': [
        {'user_id': testUserId}
      ],
    };

void main() {
  test('feedback reads bounded pages and sends reply without client author',
      () async {
    final fixture = SupabaseFixture((request) {
      if (request.url.path.contains('/rpc/')) return jsonResponse(null);
      return jsonResponse([
        {
          'id': '00000000-0000-0000-0000-000000000005',
          'author': testProfile,
          'body': 'Đẹp 😍',
          'created_at': '2026-10-16T05:00:00Z',
          'reply_to': null,
        }
      ]);
    });
    addTearDown(fixture.dispose);
    await fixture.login();
    final repo = SupabaseRepository(fixture.client);
    final first = (await repo.comments('photo')).single;
    expect(first.body, 'Đẹp 😍');
    expect(fixture.requests.last.url.queryParameters['moment_id'], 'eq.photo');
    expect(fixture.requests.last.url.queryParameters['limit'], '30');
    await repo.comments('photo', before: first);
    expect(fixture.requests.last.url.queryParameters['or'], contains(first.id));
    await repo.sendComment('photo', ' Cảm ơn ❤️ ', replyTo: first.id);
    expect(jsonDecode(fixture.requests.last.body), {
      'photo_id': 'photo',
      'message': 'Cảm ơn ❤️',
      'parent_id': first.id,
    });
    expect(fixture.requests.last.url.path, '/rest/v1/rpc/send_photo_comment');
    final count = fixture.requests.length;
    await expectLater(repo.sendComment('photo', ' '), throwsArgumentError);
    expect(fixture.requests.length, count);
  });

  test(
      'publishing uploads JPEG privately, then inserts owner, path and caption',
      () async {
    final fixture = SupabaseFixture((request) {
      if (request.url.path.startsWith('/storage/v1/object/')) {
        return jsonResponse({'Key': request.url.path.split('/object/').last});
      }
      return jsonResponse(null, status: 201);
    });
    addTearDown(fixture.dispose);
    await fixture.login();
    await SupabaseRepository(fixture.client)
        .publish(Uint8List.fromList([255, 216, 255]), '  Chào hôm nay  ');
    expect(fixture.requests, hasLength(2));
    final upload = fixture.requests.first;
    expect(upload.method, 'POST');
    expect(
        upload.url.path, startsWith('/storage/v1/object/moments/$testUserId/'));
    expect(upload.headers['content-type'], startsWith('multipart/form-data;'));
    expect(
        latin1.decode(upload.bodyBytes), contains('content-type: image/jpeg'));
    expect(upload.headers['authorization'], startsWith('Bearer '));
    final insert = fixture.requests.last;
    expect(insert.url.path, '/rest/v1/moments');
    final row = jsonDecode(insert.body) as Map;
    expect(row['author_id'], testUserId);
    expect(row['caption'], 'Chào hôm nay');
    expect(row['image_path'], upload.url.path.split('/moments/').last);
  });

  test('failed database insert cleans upload and preserves the original error',
      () async {
    for (final cleanupFails in [false, true]) {
      final fixture = SupabaseFixture((request) {
        if (request.method == 'DELETE') {
          return cleanupFails
              ? jsonResponse({
                  'message': 'cleanup denied',
                  'statusCode': '403',
                  'error': 'Unauthorized'
                }, status: 403)
              : jsonResponse([]);
        }
        if (request.url.path.startsWith('/storage/')) {
          return jsonResponse({'Key': 'uploaded'});
        }
        return jsonResponse({'message': 'insert denied', 'code': '42501'},
            status: 403);
      });
      addTearDown(fixture.dispose);
      await fixture.login();
      await expectLater(
          SupabaseRepository(fixture.client)
              .publish(Uint8List.fromList([1]), 'photo'),
          throwsA(isA<PostgrestException>()
              .having((e) => e.message, 'message', 'insert denied')));
      expect(fixture.requests.map((request) => request.method),
          ['POST', 'POST', 'DELETE']);
      final path = fixture.requests.first.url.path.split('/moments/').last;
      expect(jsonDecode(fixture.requests.last.body)['prefixes'], [path]);
    }
  });

  test('failed upload never creates a feed post', () async {
    final fixture = SupabaseFixture((_) => jsonResponse({
          'message': 'too large',
          'statusCode': '413',
          'error': 'PayloadTooLarge',
        }, status: 413));
    addTearDown(fixture.dispose);
    await fixture.login();
    await expectLater(
        SupabaseRepository(fixture.client).publish(Uint8List.fromList([1]), ''),
        throwsA(isA<StorageException>()));
    expect(fixture.requests, hasLength(1));
    expect(fixture.requests.single.url.path, startsWith('/storage/'));
  });

  test(
      'photo downloads use authenticated storage, without public or signed URLs',
      () async {
    final bytes = [255, 216, 255];
    final fixture = SupabaseFixture((_) => http.Response.bytes(bytes, 200));
    addTearDown(fixture.dispose);
    await fixture.login();
    final photo =
        await SupabaseRepository(fixture.client).photo('$testUserId/today.jpg');
    expect(photo, bytes);
    expect(fixture.requests.single.url.path,
        '/storage/v1/object/moments/$testUserId/today.jpg');
    expect(fixture.requests.single.headers['authorization'],
        startsWith('Bearer '));
  });

  test('feed maps reactions and sends a stable two-column cursor', () async {
    final fixture = SupabaseFixture((_) => jsonResponse([postJson()]));
    addTearDown(fixture.dispose);
    await fixture.login();
    final repository = SupabaseRepository(fixture.client);
    final posts = await repository.moments(mine: true);
    expect(posts.single.author.username, 'minh');
    expect(posts.single.liked, isTrue);
    expect(posts.single.likes, 1);
    await repository.moments(mine: true, before: posts.single);
    final query = fixture.requests.last.url.queryParameters;
    expect(query['author_id'], 'eq.$testUserId');
    expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
    expect(query['limit'], '20');
    expect(query['or'], contains('created_at.lt.2026-10-16T05:00:00.000Z'));
    expect(query['or'], contains('id.lt.${posts.single.id}'));
  });

  test('friend request RPCs use explicit accept/decline and trim usernames',
      () async {
    final fixture = SupabaseFixture((_) => jsonResponse(null, status: 204));
    addTearDown(fixture.dispose);
    await fixture.login();
    final repository = SupabaseRepository(fixture.client);
    await repository.requestFriend('  linh  ');
    await repository.respond('request-id', accept: false);
    expect(fixture.requests.first.url.path, '/rest/v1/rpc/send_friend_request');
    expect(
        jsonDecode(fixture.requests.first.body), {'target_username': 'linh'});
    expect(jsonDecode(fixture.requests.last.body),
        {'request_id': 'request-id', 'approve': false});
  });

  test('delete revokes post visibility before removing the stored photo',
      () async {
    final fixture = SupabaseFixture((request) =>
        request.url.path.startsWith('/storage/')
            ? jsonResponse([])
            : jsonResponse(null, status: 204));
    addTearDown(fixture.dispose);
    await fixture.login();
    await SupabaseRepository(fixture.client).deleteMoment(Moment(
        id: 'post-id',
        author: const Profile(id: testUserId, username: 'minh', name: 'Minh'),
        path: '$testUserId/today.jpg',
        caption: '',
        createdAt: DateTime.utc(2026),
        liked: false,
        likes: 0));
    expect(fixture.requests.map((request) => request.method),
        ['DELETE', 'DELETE']);
    expect(fixture.requests.first.url.path, '/rest/v1/moments');
    expect(fixture.requests.first.url.queryParameters['id'], 'eq.post-id');
    expect(jsonDecode(fixture.requests.last.body)['prefixes'],
        ['$testUserId/today.jpg']);
  });
  test(
      'profile update cannot choose an account ID and refreshes the saved profile',
      () async {
    final fixture = SupabaseFixture(
        (request) => request.url.path.endsWith('/update_profile')
            ? jsonResponse(null, status: 204)
            : jsonResponse({
                ...testProfile,
                'display_name': 'Ngọc',
                'bio': 'Một ngày đẹp',
                'avatar_emoji': '🌻',
                'avatar_color': 2
              }));
    addTearDown(fixture.dispose);
    await fixture.login();
    final profile = await SupabaseRepository(fixture.client).updateProfile(
        name: '  Ngọc  ', bio: '  Một ngày đẹp  ', emoji: '🌻', colorIndex: 2);
    expect(profile.name, 'Ngọc');
    expect(profile.bio, 'Một ngày đẹp');
    expect(profile.emoji, '🌻');
    expect(profile.colorIndex, 2);
    expect(jsonDecode(fixture.requests.first.body), {
      'new_name': 'Ngọc',
      'new_bio': 'Một ngày đẹp',
      'new_emoji': '🌻',
      'new_color': 2,
    });
    expect(fixture.requests.last.url.queryParameters['id'], 'eq.$testUserId');
  });

  test(
      'day filter uses local midnight boundaries converted to UTC and keeps the cursor',
      () async {
    final fixture = SupabaseFixture((_) => jsonResponse([postJson()]));
    addTearDown(fixture.dispose);
    await fixture.login();
    final repository = SupabaseRepository(fixture.client);
    final day = DateTime(2026, 10, 16);
    final first = await repository.moments(mine: true, onDay: day);
    await repository.moments(mine: true, onDay: day, before: first.single);
    final request = fixture.requests.last;
    final dates = request.url.queryParametersAll['created_at']!;
    expect(dates,
        contains('gte.${DateTime(2026, 10, 16).toUtc().toIso8601String()}'));
    expect(dates,
        contains('lt.${DateTime(2026, 10, 17).toUtc().toIso8601String()}'));
    expect(request.url.queryParameters['or'],
        contains('id.lt.${first.single.id}'));
    expect(request.url.queryParameters['author_id'], 'eq.$testUserId');
  });
}
