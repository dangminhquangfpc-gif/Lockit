import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockit/data/demo_repository.dart';
import 'package:lockit/main.dart';

void main() {
  test('offline photos are copied, can be liked, and disappear after logout',
      () async {
    var signedOut = false;
    final repository = DemoRepository(onSignOut: () => signedOut = true);
    final bytes = Uint8List.fromList([1, 2, 3]);
    await repository.publish(bytes, '  Hôm nay  ');
    bytes[0] = 9;
    final post = (await repository.moments()).single;
    expect(post.caption, 'Hôm nay');
    expect(await repository.photo(post.path), [1, 2, 3]);
    await repository.like(post);
    expect((await repository.moments()).single.likes, 1);
    await repository.signOut();
    expect(signedOut, isTrue);
    expect(await repository.moments(), isEmpty);
    expect(await repository.friendships(), isEmpty);
    await expectLater(repository.photo(post.path), throwsStateError);
  });

  test(
      'demo friend changes remain local and incoming invitations require acceptance',
      () async {
    final repository = DemoRepository();
    final request = (await repository.friendships()).single;
    expect(request.accepted, isFalse);
    await repository.respond(request.id, accept: true);
    expect((await repository.friendships()).single.accepted, isTrue);
    await repository.requestFriend('minh_demo');
    final outgoing = (await repository.friendships()).last;
    expect(outgoing.incoming(repository.userId), isFalse);
    await expectLater(
        repository.respond(outgoing.id, accept: true), throwsException);
    await repository.removeFriend(outgoing.id);
    expect(await repository.friendships(), hasLength(1));
  });

  testWidgets(
      'demo clearly identifies sample friends and can restart after logout',
      (tester) async {
    await tester.pumpWidget(const LockitApp(demo: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('BẢN TRẢI NGHIỆM'), findsOneWidget);
    expect(find.textContaining('không gửi cho người khác'), findsOneWidget);
    await tester.tap(find.text('Bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('@ban_demo'), findsOneWidget);
    expect(find.text('Linh (mẫu)'), findsOneWidget);
    await tester.tap(find.byTooltip('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Phiên trải nghiệm đã kết thúc'), findsOneWidget);
    await tester.tap(find.text('Trải nghiệm lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BẢN TRẢI NGHIỆM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
