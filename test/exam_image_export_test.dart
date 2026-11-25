import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/exam_document_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(ExamDocumentExporter.mediaStoreChannel, (call) async {
      calls.add(call);
      return 'Pictures/Mirsam/${(call.arguments as Map)['fileName']}';
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(ExamDocumentExporter.mediaStoreChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android image export sends the original PNG bytes to the native gallery', () async {
    final bytes = Uint8List.fromList(<int>[137, 80, 78, 71, 13, 10, 26, 10]);
    final result = await ExamDocumentExporter.exportImage(bytes, 'ورقة-1.png');
    expect(calls.single.method, 'saveImageToGallery');
    expect(calls.single.arguments['bytes'], bytes);
    expect(calls.single.arguments['fileName'], 'ورقة-1.png');
    expect(result.path, 'Pictures/Mirsam/ورقة-1.png');
    expect(result.shared, isFalse);
  });

  test('gallery image names are sanitized without duplicating a PNG extension', () async {
    await ExamDocumentExporter.exportImage(Uint8List.fromList(<int>[1]), '../exam:2.PNG');
    final name = calls.single.arguments['fileName'] as String;
    expect(name, '-exam-2.PNG');
    expect(name.toLowerCase().endsWith('.png.png'), isFalse);
  });
}
