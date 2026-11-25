import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/dimens.dart';
import '../../../data/local/exam_document_exporter.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/services/exam_paper_formatter.dart';

/// A paginated A4 reading surface. The source/ordering is the same formatter as
/// DOCX. Native Word fonts may substitute on mobile; no material is truncated.
class ExamLivePreview extends StatefulWidget {
  const ExamLivePreview({super.key, required this.paper, this.exportImage});
  final ExamPaper paper;
  final ExamDocumentExport? exportImage;
  @override
  State<ExamLivePreview> createState() => _ExamLivePreviewState();
}

class _ExamLivePreviewState extends State<ExamLivePreview> {
  static const double pageWidth = 794;
  static const double pageHeight = 1123;
  static const double margin = 48;
  final _boundary = GlobalKey();
  final _transform = TransformationController();
  int _page = 0;
  double _zoom = 1;
  bool _exporting = false;

  @override
  void didUpdateWidget(covariant ExamLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paper != widget.paper) _page = 0;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  TextStyle get _style => TextStyle(
    fontFamily: 'Amiri',
    color: Colors.black,
    fontSize: widget.paper.typography.bodyFontSize * 4 / 3,
    height: (widget.paper.typography.lineSpacingPercent / 100).clamp(1, 2).toDouble(),
  );

  /// Split paragraphs at word boundaries if they are larger than one sheet.
  List<List<String>> _paginate() {
    final pages = <List<String>>[];
    var page = <String>[];
    var height = ExamPreviewHeader.height;
    const available = pageHeight - margin * 2 - 32;
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text.isEmpty ? ' ' : text, style: _style),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: pageWidth - margin * 2);
      final h = painter.height + 4;
      painter.dispose();
      return h;
    }

    for (final line in examPaperAsPlainText(widget.paper).split('\n').skip(9)) {
      var remaining = line;
      while (true) {
        final h = measure(remaining);
        if (height + h <= available) {
          page.add(remaining);
          height += h;
          break;
        }
        if (page.isNotEmpty) {
          pages.add(page);
          page = <String>[];
          height = 0;
          continue;
        }
        final words = remaining.split(' ');
        var low = 1;
        var high = words.length;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          if (measure(words.take(mid).join(' ')) <= available) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        // Even a pathological unbroken word is allowed to wrap by TextPainter.
        if (low == words.length) {
          page.add(remaining);
          height += h;
          break;
        }
        pages.add(<String>[words.take(low).join(' ')]);
        remaining = words.skip(low).join(' ');
      }
    }
    if (page.isNotEmpty) pages.add(page);
    return pages.isEmpty ? <List<String>>[<String>[]] : pages;
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    ui.Image? image;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed');
      final Uint8List bytes = data.buffer.asUint8List();
      final name = examPaperFileName(
        widget.paper,
      ).replaceFirst(RegExp(r'\.docx$'), '-${_page + 1}.png');
      final result = await (widget.exportImage ?? ExamDocumentExporter.exportImage)(bytes, name);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر تصدير الصورة: $error')));
    } finally {
      image?.dispose();
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _setZoom(double value) {
    setState(() {
      _zoom = value.clamp(0.4, 6);
      _transform.value = Matrix4.diagonal3Values(_zoom, _zoom, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _paginate();
    final page = _page.clamp(0, pages.length - 1);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: 'تصغير المعاينة',
                onPressed: () => _setZoom(_zoom / 1.25),
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                tooltip: 'تكبير المعاينة',
                onPressed: () => _setZoom(_zoom * 1.25),
                icon: const Icon(Icons.zoom_in),
              ),
              TextButton(onPressed: () => _setZoom(1), child: const Text('ملاءمة العرض')),
              IconButton(
                tooltip: 'معاينة ملء الشاشة',
                icon: const Icon(Icons.fullscreen),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('معاينة الورقة الرسمية')),
                      body: ExamLivePreview(paper: widget.paper, exportImage: widget.exportImage),
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('export-exam-image'),
                onPressed: _exporting ? null : _exportPng,
                icon: const Icon(Icons.image_outlined),
                label: Text(_exporting ? 'جاري التصدير...' : 'تحميل الصفحة صورة PNG'),
              ),
              if (pages.length > 1) ...<Widget>[
                IconButton(
                  tooltip: 'الصفحة السابقة',
                  onPressed: page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Text('${page + 1} / ${pages.length}'),
                IconButton(
                  tooltip: 'الصفحة التالية',
                  onPressed: page + 1 < pages.length ? () => setState(() => _page++) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'A4 • المعاينة بخط أميري المضمّن؛ ملف Word يحتفظ بالخط المحدد وترويسة النموذج وجدول الدرجات.',
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => InteractiveViewer(
              transformationController: _transform,
              minScale: 0.4,
              maxScale: 6,
              child: Center(
                child: SizedBox(
                  width: constraints.maxWidth.clamp(0, pageWidth),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _boundary,
                      child: MediaQuery.withNoTextScaling(
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Container(
                            width: pageWidth,
                            height: pageHeight,
                            padding: const EdgeInsets.all(margin),
                            color: Colors.white,
                            child: DefaultTextStyle(
                              style: _style,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  if (page == 0) ExamPreviewHeader(paper: widget.paper),
                                  for (final line in pages[page])
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(line.isEmpty ? ' ' : line),
                                    ),
                                  const Spacer(),
                                  Text(
                                    '${page + 1} / ${pages.length}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The art paper's original three-column header and nine-row score table. This
/// is intentionally not the Arabic subject's composition/grammar grade split.
class ExamPreviewHeader extends StatelessWidget {
  const ExamPreviewHeader({super.key, required this.paper});
  static const double height = 370;
  final ExamPaper paper;
  @override
  Widget build(BuildContext context) {
    final info = paper.info;
    const headerStyle = TextStyle(
      fontFamily: 'Amiri',
      color: Colors.black,
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.bold,
    );
    Widget cell(String text) => Padding(
      padding: const EdgeInsets.all(3),
      child: Text(text, style: headerStyle, textAlign: TextAlign.center),
    );
    TableRow scoreRow(String text) =>
        TableRow(children: <Widget>[cell(text), cell(''), cell(''), cell(''), cell('')]);
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 2693, child: cell('ادارة\n${info.school}')),
                Expanded(
                  flex: 5245,
                  child: cell('${info.examTitleLine}\n${info.yearLine}\nالتربية الفنية'),
                ),
                Expanded(flex: 2977, child: cell('الاسم :\n${info.classLine}\nالرقم الامتحاني :')),
              ],
            ),
          ),
          Center(
            child: SizedBox(
              width: 500,
              child: Column(
                children: <Widget>[
                  Table(
                    border: TableBorder.all(color: Colors.black, width: 0.7),
                    children: <TableRow>[
                      TableRow(
                        children: <Widget>[
                          cell('رقم السؤال'),
                          cell('الدرجة رقما'),
                          cell('الدرجة كتابة'),
                          cell('اسم المصحح'),
                          cell('اسم المدقق'),
                        ],
                      ),
                      scoreRow('س1'),
                      scoreRow('س2'),
                      scoreRow('س3'),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.7)),
                    child: cell('العملـــــي'),
                  ),
                  Table(
                    border: TableBorder.all(color: Colors.black, width: 0.7),
                    children: <TableRow>[
                      scoreRow('س1'),
                      scoreRow('س2'),
                      scoreRow('س3'),
                      scoreRow('المجموع'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
