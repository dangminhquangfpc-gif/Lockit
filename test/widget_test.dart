import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockit/data/models.dart';
import 'package:lockit/main.dart';
import 'package:lockit/ui/camera_page.dart';
import 'package:lockit/ui/friends_page.dart';
import 'package:lockit/ui/social_home.dart';

const me = Profile(id: 'me', username: 'minh', name: 'Minh');
const friend = Profile(id: 'friend', username: 'linh', name: 'Linh');

class FakeRepository implements SocialRepository {
  List<Friendship> connections = [];
  List<Moment> posts = [];
  final List<String> requests = [];
  final List<String> accepted = [];
  final List<String> removed = [];
  bool offline = false;
  bool loggedOut = false;
  @override
  String get userId => me.id;
  @override
  Future<Profile> profile() async => me;
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
  Future<List<Moment>> moments({bool mine = false, Moment? before}) async {
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
}

Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test('usernames reject invalid identifiers and passwords enforce minimum',
      () {
    expect(usernameError('minh_123'), isNull);
    for (final value in ['', 'ab', 'Minh', 'hai ban', 'a' * 25]) {
      expect(usernameError(value), isNotNull);
    }
    expect(passwordError('1234567'), isNotNull);
    expect(passwordError('12345678'), isNull);
  });

  testWidgets('unconfigured app shows a safe setup state without crashing',
      (tester) async {
    await tester.pumpWidget(const LockitApp());
    expect(find.text('Lockit'), findsOneWidget);
    expect(find.textContaining('đang được chuẩn bị'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend request validates username before calling repository',
      (tester) async {
    final repository = FakeRepository();
    await tester.pumpWidget(app(FriendsPage(repository: repository, me: me)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi lời mời'));
    await tester.pumpAndSettle();
    expect(repository.requests, isEmpty);
    expect(find.textContaining('3–24'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'linh');
    await tester.tap(find.text('Gửi lời mời'));
    await tester.pumpAndSettle();
    expect(repository.requests, ['linh']);
    expect(find.text('Đã gửi lời mời kết bạn.'), findsOneWidget);
  });

  testWidgets('recipient can accept an incoming request', (tester) async {
    final repository = FakeRepository()
      ..connections = [
        const Friendship(
            id: 'request', senderId: 'friend', accepted: false, other: friend),
      ];
    await tester.pumpWidget(app(FriendsPage(repository: repository, me: me)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Chấp nhận'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Chấp nhận'));
    await tester.pumpAndSettle();
    expect(repository.accepted, ['request']);
  });

  testWidgets('outgoing request offers cancellation without self-accept',
      (tester) async {
    final repository = FakeRepository()
      ..connections = [
        const Friendship(
            id: 'sent', senderId: 'me', accepted: false, other: friend),
      ];
    await tester.pumpWidget(app(FriendsPage(repository: repository, me: me)));
    await tester.pumpAndSettle();
    expect(find.text('Chấp nhận'), findsNothing);
    await tester.scrollUntilVisible(find.text('Thu hồi lời mời'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Thu hồi lời mời'));
    await tester.pumpAndSettle();
    expect(repository.removed, ['sent']);
  });

  testWidgets('empty feed offers capture and fetch failures offer retry',
      (tester) async {
    final repository = FakeRepository();
    await tester.pumpWidget(app(MomentFeed(
        repository: repository, mine: false, name: 'Minh', onCapture: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Chụp ảnh đầu tiên'), findsOneWidget);
    repository.offline = true;
    await tester.pumpWidget(app(MomentFeed(
        key: const ValueKey('offline'),
        repository: repository,
        mine: false,
        name: 'Minh',
        onCapture: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    repository.offline = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp ảnh đầu tiên'), findsOneWidget);
  });

  testWidgets(
      'camera failure displays recovery instead of accessing cameras[0]',
      (tester) async {
    await tester.pumpWidget(app(
        CameraPage(repository: FakeRepository(), loadCameras: () async => [])));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation switches to friends and supports sign out',
      (tester) async {
    final repository = FakeRepository();
    await tester
        .pumpWidget(MaterialApp(home: SocialHome(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('@minh'), findsOneWidget);
    await tester.tap(find.byTooltip('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repository.loggedOut, isTrue);
  });
}
