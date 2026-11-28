import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifin/app/attachment_picker.dart';
import 'package:verifin/app/attachments/attachment_store.dart';
import 'package:verifin/app/models.dart';
import 'package:verifin/app/veri_fin_scope.dart';
import 'package:verifin/pages/attachments_editor.dart';
import 'package:verifin/pages/entry_detail_page.dart';

import 'support/test_harness.dart';

// 合法的 1x1 PNG，供需要真实解码的缩略图使用。
const String _png =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

Uint8List _pngBytes() => base64Decode(_png.substring(_png.indexOf(',') + 1));

Uint8List _fakeImage(int marker) => Uint8List.fromList(<int>[marker]);

void main() {
  useTestDatabases();

  tearDown(() => debugAttachmentPickImagesOverride = null);

  testWidgets('批量添加期间显示不可关闭的进度弹窗并按顺序逐张回调', (tester) async {
    final gate = Completer<void>();
    final images = <Uint8List>[_fakeImage(1), _fakeImage(2), _fakeImage(3)];
    debugAttachmentPickImagesOverride =
        ({
          required bool fromCamera,
          required Future<bool> Function(Uint8List bytes) onImage,
          void Function(int done, int total)? onProgress,
        }) async {
          expect(fromCamera, isFalse);
          onProgress?.call(1, 3);
          await onImage(images[0]);
          await gate.future;
          onProgress?.call(2, 3);
          await onImage(images[1]);
          onProgress?.call(3, 3);
          await onImage(images[2]);
          return const AttachmentPickOutcome(picked: 3, added: 3, failed: 0);
        };

    final added = <Uint8List>[];
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                pickAndAddAttachments(
                  context: context,
                  fromCamera: false,
                  onAddBytes: (bytes) async => added.add(bytes),
                ),
              ),
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('正在添加图片 1/3'), findsOneWidget);

    // 点遮罩不能关闭弹窗，批量处理期间页面被完整挡住。
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    expect(find.text('正在添加图片 1/3'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(added, images);
  });

  testWidgets('部分图片无法读取时提示已添加与跳过数量', (tester) async {
    debugAttachmentPickImagesOverride =
        ({
          required bool fromCamera,
          required Future<bool> Function(Uint8List bytes) onImage,
          void Function(int done, int total)? onProgress,
        }) async {
          onProgress?.call(1, 3);
          await onImage(_fakeImage(1));
          onProgress?.call(2, 3);
          await onImage(_fakeImage(2));
          return const AttachmentPickOutcome(picked: 3, added: 2, failed: 1);
        };

    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                pickAndAddAttachments(
                  context: context,
                  fromCamera: false,
                  onAddBytes: (_) async {},
                ),
              ),
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('已添加 2 张，1 张无法读取'), findsOneWidget);
  });

  testWidgets('全部图片无法读取时提示换一批', (tester) async {
    debugAttachmentPickImagesOverride =
        ({
          required bool fromCamera,
          required Future<bool> Function(Uint8List bytes) onImage,
          void Function(int done, int total)? onProgress,
        }) async => const AttachmentPickOutcome(picked: 2, added: 0, failed: 2);

    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                pickAndAddAttachments(
                  context: context,
                  fromCamera: false,
                  onAddBytes: (_) async {},
                ),
              ),
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('所选图片无法读取，请换一批试试'), findsOneWidget);
  });

  testWidgets('记账页附件 chip 接入批量选择并把多张图加入草稿', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1100);
    addTearDown(tester.view.reset);

    final gate = Completer<void>();
    final images = <Uint8List>[_pngBytes(), _pngBytes()];
    debugAttachmentPickImagesOverride =
        ({
          required bool fromCamera,
          required Future<bool> Function(Uint8List bytes) onImage,
          void Function(int done, int total)? onProgress,
        }) async {
          expect(fromCamera, isFalse);
          onProgress?.call(1, 2);
          await onImage(images[0]);
          await gate.future;
          onProgress?.call(2, 2);
          await onImage(images[1]);
          return const AttachmentPickOutcome(picked: 2, added: 2, failed: 0);
        };

    final controller = await makeController();
    await tester.pumpWidget(
      VeriFinScope(
        controller: controller,
        child: zhMaterialApp(home: const EntryDetailPage(initialAmount: 30)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('entry_metadata_attachments')));
    await tester.pumpAndSettle();
    expect(find.text('可一次选择多张'), findsOneWidget);

    await tester.tap(find.text('从相册选择'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('正在添加图片 1/2'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('附件 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('attachment_remove_visual_1')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('attachment_remove_visual_0')), findsOneWidget);
    expect(find.byKey(const Key('attachment_remove_visual_1')), findsOneWidget);
  });

  testWidgets('交易详情附件卡的添加按钮同样走批量选择', (tester) async {
    debugAttachmentPickImagesOverride =
        ({
          required bool fromCamera,
          required Future<bool> Function(Uint8List bytes) onImage,
          void Function(int done, int total)? onProgress,
        }) async {
          onProgress?.call(1, 2);
          await onImage(_fakeImage(1));
          onProgress?.call(2, 2);
          await onImage(_fakeImage(2));
          return const AttachmentPickOutcome(picked: 2, added: 2, failed: 0);
        };

    final added = <Uint8List>[];
    await tester.pumpWidget(
      zhMaterialApp(
        home: Scaffold(
          body: AttachmentsEditor(
            attachments: const <Attachment>[],
            store: InMemoryAttachmentStore(),
            onAddBytes: (bytes) async => added.add(bytes),
            onRemoveIndex: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    expect(find.text('可一次选择多张'), findsOneWidget);
    await tester.tap(find.text('从相册选择'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(added, hasLength(2));
  });
}
