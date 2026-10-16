import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockit/data/demo_repository.dart';
import 'package:lockit/data/models.dart';
import 'package:lockit/ui/comments_page.dart';
import 'support/fake_social_repository.dart';

final moment = Moment(
    id: 'photo',
    author: me,
    path: 'photo',
    caption: '',
    createdAt: DateTime(2026),
    liked: false,
    likes: 0);

void main() {
  test('demo feedback replies, pagination, validation and photo deletion',
      () async {
    final repo = DemoRepository();
    await repo.publish(Uint8List(1), '');
    final photo = (await repo.moments()).single;
    repo.addSampleComment(photo.id);
    final sample = (await repo.comments(photo.id)).single;
    await repo.sendComment(photo.id, ' Cảm ơn ❤️ ', replyTo: sample.id);
    final rows = await repo.comments(photo.id);
    expect(rows.first.replyTo, sample.id);
    expect(rows.first.body, 'Cảm ơn ❤️');
    await expectLater(repo.sendComment(photo.id, '  '), throwsArgumentError);
    await expectLater(
        repo.sendComment(photo.id, 'x', replyTo: 'missing'), throwsStateError);
    for (var i = 0; i < 31; i++) {
      await repo.sendComment(photo.id, 'test $i');
    }
    final first = await repo.comments(photo.id);
    final next = await repo.comments(photo.id, before: first.last);
    expect(first.length, 30);
    expect(next.length, 3);
    expect({...first.map((c) => c.id), ...next.map((c) => c.id)}.length, 33);
    await repo.deleteMoment(photo);
    expect(await repo.comments(photo.id), isEmpty);
  });

  testWidgets('reply quote, emoji at cursor and sending clears composer',
      (tester) async {
    final repo = FakeRepository();
    repo.feedback.add(PhotoComment(
        id: 'friend-comment',
        author: friend,
        body: 'Đẹp quá',
        createdAt: DateTime.now()));
    await tester.pumpWidget(
        MaterialApp(home: CommentsPage(moment: moment, repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trả lời'));
    await tester.pumpAndSettle();
    expect(find.text('Trả lời Linh'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Cảm ơn ');
    await tester.tap(find.text('❤️'));
    await tester.tap(find.byTooltip('Gửi phản hồi'));
    await tester.pumpAndSettle();
    expect(repo.feedback.last.body, 'Cảm ơn ❤️');
    expect(repo.feedback.last.replyTo, 'friend-comment');
    expect(find.text('↪ Linh: Đẹp quá'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('failed send preserves draft for retry', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(
        MaterialApp(home: CommentsPage(moment: moment, repository: repo)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Giữ bản nháp');
    repo.offline = true;
    await tester.tap(find.byTooltip('Gửi phản hồi'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Giữ bản nháp');
    expect(repo.feedback, isEmpty);
    repo.offline = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gửi phản hồi'));
    await tester.pumpAndSettle();
    expect(repo.feedback.single.body, 'Giữ bản nháp');
  });

  testWidgets('emoji replaces selection and load error can be retried',
      (tester) async {
    final repo = FakeRepository()..offline = true;
    await tester.pumpWidget(
        MaterialApp(home: CommentsPage(moment: moment, repository: repo)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thử lại'), findsOneWidget);
    repo.offline = false;
    await tester.tap(find.textContaining('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có phản hồi'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc');
    final controller =
        tester.widget<TextField>(find.byType(TextField)).controller!;
    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
    await tester.tap(find.text('❤️'));
    expect(controller.text, 'a❤️c');
    expect(controller.selection.baseOffset, 'a❤️'.length);
  });

  testWidgets('composer and feedback fit a narrow screen with keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
        home: CommentsPage(moment: moment, repository: FakeRepository())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '😍');
    await tester.tap(find.byTooltip('Gửi phản hồi'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('unicode comment limit counts code points', () {
    expect(commentError(List.filled(500, '😍').join()), isNull);
    expect(commentError(List.filled(501, '😍').join()), isNotNull);
    expect(commentError(' \n '), isNotNull);
  });
}
