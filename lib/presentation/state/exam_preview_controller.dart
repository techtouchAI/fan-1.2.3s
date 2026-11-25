import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared by embedded and full-screen previews. Gestures and buttons read the
/// same transform, so button zoom never starts from a stale scale or drops pan.
class ExamPreviewController extends ChangeNotifier {
  ExamPreviewController() {
    transformation.addListener(notifyListeners);
  }
  static const double minZoom = 0.4;
  static const double maxZoom = 6;
  final transformation = TransformationController();
  int _page = 0;
  double get zoom => transformation.value.getMaxScaleOnAxis();
  int visiblePage(int pageCount) => _page.clamp(0, math.max(0, pageCount - 1));

  void goToPage(int page, {required int pageCount}) {
    final next = page.clamp(0, math.max(0, pageCount - 1));
    if (_page == next) return;
    _page = next;
    notifyListeners();
  }

  /// Preserve the scene point under the viewport centre (or a supplied anchor).
  void setZoom(double value, {required Offset focalPoint}) {
    if (!value.isFinite || value <= 0) return;
    final scene = transformation.toScene(focalPoint);
    final scale = value.clamp(minZoom, maxZoom);
    transformation.value = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(scale)
      ..translate(-scene.dx, -scene.dy);
  }

  /// The page is first contained by a FittedBox. Account for that base scale,
  /// rather than assuming that transform=identity means fitting the width.
  void fitWidth({required Size viewport, required Size page}) {
    if (viewport.isEmpty || page.isEmpty) return;
    final baseScale = math.min(
      1.0,
      math.min(viewport.width / page.width, viewport.height / page.height),
    );
    final scale = (viewport.width / (page.width * baseScale)).clamp(minZoom, maxZoom);
    final left = (viewport.width - page.width * baseScale) / 2;
    final top = (viewport.height - page.height * baseScale) / 2;
    // Fit is an explicit reset; incremental zoom preserves the current pan.
    transformation.value = Matrix4.identity()
      ..translate(-left * scale, -top * scale)
      ..scale(scale);
  }

  @override
  void dispose() {
    transformation.removeListener(notifyListeners);
    transformation.dispose();
    super.dispose();
  }
}
