import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/exam_document_exporter.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/presentation/services/exam_page_image_capture.dart';
import 'package:mirsam/presentation/state/exam_preview_controller.dart';
import 'package:mirsam/presentation/widgets/exam/exam_live_preview.dart';

import 'docx_test_support.dart';
import 'test_support.dart';

Future<ui.Image> renderTestPage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xffffffff), ui.BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('button zoom uses the gesture scale and preserves the focal scene point', () {
    final controller = ExamPreviewController();
    addTearDown(controller.dispose);
    controller.transformation.value = Matrix4.identity()
      ..translate(50.0, 20.0)
      ..scale(2.0);
    const focal = Offset(200, 250);
    final before = controller.transformation.toScene(focal);
    expect(controller.zoom, 2);
    controller.setZoom(controller.zoom * 1.25, focalPoint: focal);
    final after = controller.transformation.toScene(focal);
    expect(controller.zoom, closeTo(2.5, 1e-9));
    expect(after.dx, closeTo(before.dx, 1e-9));
    expect(after.dy, closeTo(before.dy, 1e-9));
    expect(controller.transformation.value.getTranslation().x, isNot(0));
  });

  test('fit width accounts for the base page containment and resets to page top', () {
    final controller = ExamPreviewController();
    addTearDown(controller.dispose);
    const page = Size(794, 1123);
    const viewport = Size(1200, 500);
    controller.fitWidth(viewport: viewport, page: page);
    final base = math.min(
      1.0,
      math.min(viewport.width / page.width, viewport.height / page.height),
    );
    expect(page.width * base * controller.zoom, closeTo(viewport.width, 1e-8));
    final topLeft = controller.transformation.toScene(Offset.zero);
    expect(topLeft.dx, closeTo((viewport.width - page.width * base) / 2, 1e-8));
    expect(topLeft.dy, closeTo((viewport.height - page.height * base) / 2, 1e-8));
    expect(controller.zoom, isNot(1));
  });

  test('page and scale limits never select an invalid page or transform', () {
    final controller = ExamPreviewController();
    addTearDown(controller.dispose);
    controller.goToPage(20, pageCount: 3);
    expect(controller.visiblePage(3), 2);
    expect(controller.visiblePage(1), 0);
    controller.goToPage(-1, pageCount: 3);
    expect(controller.visiblePage(3), 0);
    controller.setZoom(double.nan, focalPoint: Offset.zero);
    expect(controller.zoom, 1);
    controller.setZoom(100, focalPoint: Offset.zero);
    expect(controller.zoom, ExamPreviewController.maxZoom);
  });

  testWidgets('full-screen preview preserves the selected page, zoom and pan', (tester) async {
    final controller = ExamPreviewController();
    addTearDown(controller.dispose);
    final paper = buildSamplePaper().copyWith(
      practical: <ExamPracticalQuestion>[
        ExamPracticalQuestion(prompt: List<String>.filled(500, 'كلمةاختبار').join(' '), degree: 35),
      ],
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: ExamLivePreview(paper: paper, controller: controller),
      ),
      size: const Size(900, 1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('الصفحة التالية'));
    await tester.pumpAndSettle();
    controller.transformation.value = Matrix4.identity()
      ..translate(20.0, 15.0)
      ..scale(1.5);
    await tester.pump();
    final before = controller.transformation.value.storage.toList();
    expect(controller.visiblePage(100), 1);
    await tester.tap(find.byTooltip('معاينة ملء الشاشة'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ExamLivePreview>(find.byType(ExamLivePreview)).controller,
      same(controller),
    );
    expect(controller.visiblePage(100), 1);
    expect(controller.transformation.value.storage.toList(), before);
    expect(find.byTooltip('معاينة ملء الشاشة'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(controller.visiblePage(100), 1);
    expect(controller.transformation.value.storage.toList(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PNG capture retries at lower resolution and produces a decodable image', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final scales = <double>[];
      final captured = await const ExamPageImageCapture().capture(
        logicalSize: const Size(80, 120),
        render: (scale) async {
          scales.add(scale);
          if (scales.length == 1) throw StateError('Simulated render pressure');
          return renderTestPage((80 * scale).ceil(), (120 * scale).ceil());
        },
      );
      expect(scales.length, 2);
      expect(scales.last, lessThan(scales.first));
      expect(captured.bytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(captured.bytes);
      try {
        final frame = await codec.getNextFrame();
        expect(frame.image.width, captured.width);
        expect(frame.image.height, captured.height);
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    });
  });

  testWidgets('image budgets cap dimensions and all-failed capture propagates the last error', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final captured = await const ExamPageImageCapture(maxDimension: 64, maxPixels: 4096).capture(
        logicalSize: const Size(800, 1200),
        render: (scale) => renderTestPage((800 * scale).ceil(), (1200 * scale).ceil()),
      );
      expect(captured.width, lessThanOrEqualTo(64));
      expect(captured.height, lessThanOrEqualTo(64));
      expect(captured.width * captured.height, lessThanOrEqualTo(4096));
      var attempts = 0;
      await expectLater(
        const ExamPageImageCapture().capture(
          logicalSize: const Size(8, 12),
          render: (_) async {
            attempts++;
            throw StateError('last-$attempts');
          },
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'cause', 'last-3')),
      );
      expect(attempts, 3);
    });
  });

  testWidgets('successful gallery save offers sharing of the same captured page bytes', (
    tester,
  ) async {
    final exported = Completer<void>();
    final shared = Completer<void>();
    Uint8List? savedBytes;
    String? savedName;
    await pumpScreen(
      tester,
      Scaffold(
        body: ExamLivePreview(
          paper: buildSamplePaper(),
          exportImage: (bytes, name) async {
            savedBytes = bytes;
            savedName = name;
            exported.complete();
            return const ExamExportResult(
              message: 'حُفظت الصورة في المعرض',
              path: 'content://gallery/page',
            );
          },
          shareImage: (bytes, name) async {
            expect(bytes, savedBytes);
            expect(name, savedName);
            shared.complete();
            return const ExamExportResult(message: 'جُهزت المشاركة', shared: true);
          },
        ),
      ),
      size: const Size(900, 1000),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey<String>('export-exam-image')));
      await tester.pump();
      await exported.future.timeout(const Duration(seconds: 30));
    });
    await tester.pumpAndSettle();
    expect(savedBytes!.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    expect(savedName, endsWith('-1.png'));
    expect(find.text('مشاركة'), findsOneWidget);
    await tester.tap(find.text('مشاركة'));
    await tester.pumpAndSettle();
    await shared.future;
    expect(find.text('جُهزت المشاركة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
