import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockit/data/demo_repository.dart';
import 'package:lockit/data/models.dart';
import 'package:lockit/main.dart';
import 'package:lockit/ui/friends_page.dart';
import 'package:lockit/ui/moment_card.dart';
import 'package:lockit/ui/profile_avatar.dart';
import 'package:lockit/ui/profile_page.dart';
import 'package:lockit/ui/social_home.dart';
import 'support/fake_social_repository.dart';

class PhotoRepository extends FakeRepository {
  int photoRequests = 0;
  @override
  Future<Uint8List> photo(String path) async {
    photoRequests++;
    return base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==');
  }
}

void main() {
  test(
      'legacy profiles remain readable and calendar boundaries cross month/year correctly',
      () {
    final profile = Profile.fromJson(
        {'id': 'me', 'username': 'minh', 'display_name': 'Minh'});
    expect(profile.bio, '');
    expect(profile.emoji, '');
    expect(profile.colorIndex, 0);
    expect(nextLocalDay(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
    expect(nextLocalDay(DateTime(2028, 2, 28)), DateTime(2028, 2, 29));
    expect(displayNameError('   '), isNotNull);
    expect(displayNameError('a' * 41), isNotNull);
    expect(bioError('a' * 81), isNotNull);
    expect(normalizeUsername(' @Linh_Demo '), 'linh_demo');
  });

  test('demo profile edits also update authors on existing moments', () async {
    final repository = DemoRepository();
    await repository.publish(Uint8List.fromList([1]), 'Hôm nay');
    await repository.updateProfile(
        name: '  Ngọc  ', bio: '  Bầu trời xanh  ', emoji: '🌊', colorIndex: 3);
    final post = (await repository.moments()).single;
    expect(post.author.name, 'Ngọc');
    expect(post.author.bio, 'Bầu trời xanh');
    expect(post.author.emoji, '🌊');
    expect(post.author.username, 'ban_demo');
    expect(await repository.moments(onDay: DateTime(2000)), isEmpty);
    expect(await repository.moments(onDay: DateTime.now()), hasLength(1));
    await expectLater(
        repository.updateProfile(name: '', bio: '', emoji: '', colorIndex: 0),
        throwsArgumentError);
  });

  testWidgets(
      'profile edits save through navigation and remain visible when reopened',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LockitApp(demo: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '🌻'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ngọc');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Một chút bình yên');
    await tester.ensureVisible(find.text('Lưu hồ sơ'));
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Chào Ngọc ☀'), findsOneWidget);
    await tester.tap(find.byTooltip('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'Ngọc');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Một chút bình yên');
    expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).profile.emoji,
        '🌻');
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid profile is rejected before saving', (tester) async {
    final repository = FakeRepository();
    await tester.pumpWidget(
        MaterialApp(home: ProfilePage(repository: repository, profile: me)));
    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.ensureVisible(find.text('Lưu hồ sơ'));
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên từ 1 đến 40 ký tự.'), findsOneWidget);
    expect(repository.profileWrites, 0);
  });

  testWidgets('failed profile save retains input and can be retried',
      (tester) async {
    final repository = FakeRepository();
    await tester
        .pumpWidget(MaterialApp(home: SocialHome(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();
    repository.offline = true;
    await tester.enterText(find.byType(TextFormField).first, 'Tên mới');
    await tester.ensureVisible(find.text('Lưu hồ sơ'));
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kiểm tra kết nối'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'Tên mới');
    repository.offline = false;
    await tester.ensureVisible(find.text('Lưu hồ sơ'));
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Chào Tên mới ☀'), findsOneWidget);
    expect(repository.profileWrites, 1);
  });

  testWidgets('memories can select a calendar day and clear the filter',
      (tester) async {
    final repository = FakeRepository();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MomentFeed(
                repository: repository,
                mine: true,
                name: 'Minh',
                onCapture: () {}))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-memory-day')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(repository.requestedMine, isTrue);
    expect(sameLocalDay(repository.requestedDay!, DateTime.now()), isTrue);
    expect(find.text('Chưa có ảnh ngày này'), findsOneWidget);
    await tester.ensureVisible(find.text('Tất cả ngày'));
    await tester.tap(find.text('Tất cả ngày'));
    await tester.pumpAndSettle();
    expect(repository.requestedDay, isNull);
  });

  testWidgets('friend search filters locally and accepts pasted @usernames',
      (tester) async {
    final repository = FakeRepository()
      ..connections = [
        const Friendship(
            id: 'linh', senderId: 'me', accepted: true, other: friend),
      ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: FriendsPage(repository: repository, me: me))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), ' @NEW_FRIEND ');
    await tester.tap(find.text('Gửi lời mời'));
    await tester.pumpAndSettle();
    expect(repository.requests, ['new_friend']);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '');
    final search = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Tìm trong danh sách bạn bè');
    await tester.ensureVisible(search);
    await tester.enterText(search, 'không có');
    await tester.pumpAndSettle();
    expect(find.text('Chưa tìm thấy người bạn này'), findsOneWidget);
    await tester.enterText(search, '@linh');
    await tester.pumpAndSettle();
    expect(find.text('Linh'), findsOneWidget);
  });

  testWidgets('a photo opens a full screen viewer with pinch zoom',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final moment = Moment(
          id: 'photo',
          author: me,
          path: 'photo',
          caption: 'Một ngày đẹp',
          createdAt: DateTime.now(),
          liked: false,
          likes: 0);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: MomentCard(
                      moment: moment,
                      repository: PhotoRepository(),
                      onChanged: () async {})))));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('Xem ảnh của Minh')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Dùng hai ngón tay để phóng to ảnh'), findsOneWidget);
      expect(find.text('Một ngày đẹp'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('the feed downloads photos lazily as they become visible',
      (tester) async {
    final repository = PhotoRepository()
      ..posts = List.generate(
          20,
          (index) => Moment(
              id: 'post-$index',
              author: me,
              path: 'photo-$index',
              caption: 'Ảnh $index',
              createdAt: DateTime.now().subtract(Duration(minutes: index)),
              liked: false,
              likes: 0));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MomentFeed(
                repository: repository,
                mine: true,
                name: 'Minh',
                onCapture: () {}))));
    await tester.pumpAndSettle();
    final initial = repository.photoRequests;
    expect(initial, greaterThan(0));
    expect(initial, lessThan(5));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(repository.photoRequests, greaterThan(initial));
  });

  testWidgets('a long username fits on a narrow profile screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeRepository();
    await tester.pumpWidget(MaterialApp(
        home: ProfilePage(
            repository: repository,
            profile: Profile(id: 'me', username: 'a' * 24, name: 'Minh'))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sao chép tên người dùng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
