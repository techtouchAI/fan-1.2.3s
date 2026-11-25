import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/exam_paper_formatter.dart';
import 'docx/exam_docx_builder.dart';

enum ExamExportStatus { completed, handedOff, cancelled }

/// Outcome of an export, reported to the teacher in a snack bar.
class ExamExportResult {
  const ExamExportResult({
    required this.message,
    this.path,
    this.shared = false,
    this.status = ExamExportStatus.completed,
  });
  final ExamExportStatus status;
  bool get wasCancelled => status == ExamExportStatus.cancelled;

  final String message;

  /// Absolute path of the written file, when one was produced.
  final String? path;

  /// True when the file was handed to the system share sheet (phone).
  final bool shared;
}

/// Signature of the platform save/share step, replaceable in the UI tests.
typedef ExamDocumentExport = Future<ExamExportResult> Function(Uint8List bytes, String fileName);

/// Writes the Word file where the teacher can reach it, offline.
///
/// Mobile documents use the native share sheet; desktop exports use Save As.
/// Android 10+ images go to Pictures/Mirsam without storage permissions.
abstract final class ExamDocumentExporter {
  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get _isMobile => _isAndroid || defaultTargetPlatform == TargetPlatform.iOS;

  static const mediaStoreChannel = MethodChannel('com.techtouchai.mirsam/media_store');

  static Future<ExamExportResult> _saveAs(Uint8List bytes, String name, String extension) async {
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: extension == 'png' ? 'PNG Image' : 'Microsoft Word',
          extensions: <String>[extension],
        ),
      ],
    );
    if (location == null)
      return const ExamExportResult(message: 'أُلغي الحفظ', status: ExamExportStatus.cancelled);
    final path = location.path.toLowerCase().endsWith('.$extension')
        ? location.path
        : '${location.path}.$extension';
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return ExamExportResult(message: 'حُفظ الملف في: ${file.path}', path: file.path);
  }

  static Future<ExamExportResult> export(Uint8List bytes, String fileName) async {
    final name = fileName.trim().isEmpty ? 'mirsam-exam.docx' : sanitizeExamFileName(fileName);
    final safeName = name.toLowerCase().endsWith('.docx') ? name : '$name.docx';

    if (_isMobile) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes, flush: true);
      final share = await Share.shareXFiles(<XFile>[
        XFile(file.path, mimeType: ExamDocxBuilder.mimeType),
      ], subject: safeName);
      return ExamExportResult(
        status: share.status == ShareResultStatus.dismissed
            ? ExamExportStatus.cancelled
            : ExamExportStatus.handedOff,
        message: share.status == ShareResultStatus.dismissed
            ? 'أُلغيت المشاركة؛ بقي الملف المؤقت جاهزاً'
            : 'تم تجهيز ملف الوورد للمشاركة: $safeName',
        path: file.path,
        shared: true,
      );
    }

    return _saveAs(bytes, safeName, 'docx');
  }

  /// Save/share the current A4 preview page without mislabelling it as DOCX.
  static Future<ExamExportResult> exportImage(Uint8List bytes, String fileName) async {
    final name = sanitizeExamFileName(fileName);
    final safeName = name.toLowerCase().endsWith('.png') ? name : '$name.png';
    if (!_isMobile) return _saveAs(bytes, safeName, 'png');
    if (_isAndroid) {
      try {
        final path = await mediaStoreChannel.invokeMethod<String>(
          'saveImageToGallery',
          <String, Object>{'bytes': bytes, 'fileName': safeName},
        );
        if (path != null && path.isNotEmpty) {
          return ExamExportResult(message: 'حُفظت الصورة في المعرض: $path', path: path);
        }
      } on MissingPluginException {
        // Older Android versions and hosts without the channel use sharing.
      } on PlatformException {
        // Sharing remains available if the gallery provider cannot save.
      }
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(bytes, flush: true);
    final share = await Share.shareXFiles(<XFile>[
      XFile(file.path, mimeType: 'image/png'),
    ], subject: safeName);
    return ExamExportResult(
      status: share.status == ShareResultStatus.dismissed
          ? ExamExportStatus.cancelled
          : ExamExportStatus.handedOff,
      message: share.status == ShareResultStatus.dismissed
          ? 'أُلغيت مشاركة الصورة'
          : 'تم تجهيز الصورة للمشاركة',
      path: file.path,
      shared: true,
    );
  }
}
