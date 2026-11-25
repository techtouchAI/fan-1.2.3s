import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class CapturedExamPage {
  const CapturedExamPage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.pixelRatio,
  });
  final Uint8List bytes;
  final int width;
  final int height;
  final double pixelRatio;
}

/// Bounded high-resolution capture, independent of zoom and viewport pixels.
/// Render failures retry at lower resolutions; every native image is disposed.
class ExamPageImageCapture {
  const ExamPageImageCapture({
    this.targetDpi = 300,
    this.maxDimension = 4096,
    this.maxPixels = 16 * 1024 * 1024,
  });
  final double targetDpi;
  final int maxDimension;
  final int maxPixels;

  Future<CapturedExamPage> capture({
    required ui.Size logicalSize,
    required Future<ui.Image> Function(double pixelRatio) render,
  }) async {
    if (logicalSize.isEmpty ||
        !logicalSize.width.isFinite ||
        !logicalSize.height.isFinite ||
        !(logicalSize.width * logicalSize.height).isFinite ||
        !targetDpi.isFinite ||
        targetDpi <= 0 ||
        maxDimension < 1 ||
        maxPixels < 1) {
      throw ArgumentError('A finite page size and positive image budgets are required');
    }
    final ratio = math.min(
      targetDpi / 96,
      math.min(
        maxDimension / math.max(logicalSize.width, logicalSize.height),
        math.sqrt(maxPixels / (logicalSize.width * logicalSize.height)),
      ),
    );
    final scales = <double>[ratio, ratio * 2 / 3, ratio / 3];
    for (final (attempt, scale) in scales.indexed) {
      ui.Image? image;
      try {
        image = await render(scale);
        if (image.width > maxDimension ||
            image.height > maxDimension ||
            image.width * image.height > maxPixels) {
          throw StateError('Renderer exceeded the image budget');
        }
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null || data.lengthInBytes == 0) throw StateError('PNG encoding failed');
        return CapturedExamPage(
          bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          width: image.width,
          height: image.height,
          pixelRatio: scale,
        );
      } catch (error, stack) {
        if (attempt == scales.length - 1) Error.throwWithStackTrace(error, stack);
      } finally {
        image?.dispose();
      }
    }
    throw StateError('No capture attempts available');
  }
}
