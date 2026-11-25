import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/dimens.dart';
import '../../../data/local/exam_document_exporter.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/services/exam_paper_formatter.dart';
import '../../state/exam_preview_controller.dart';
import '../../services/exam_page_image_capture.dart';

/// A paginated A4 reading surface. The source/ordering is the same formatter as
/// DOCX. Native Word fonts may substitute on mobile; no material is truncated.
class ExamLivePreview extends StatefulWidget {
  const ExamLivePreview({
    super.key,
    required this.paper,
    this.exportImage,
    this.shareImage,
    this.controller,
    this.showFullscreenButton = true,
  });
  final ExamPaper paper;
  final ExamDocumentExport? exportImage;
  final ExamDocumentExport? shareImage;
  final ExamPreviewController? controller;
  final bool showFullscreenButton;
  @override
  State<ExamLivePreview> createState() => _ExamLivePreviewState();
}

class _ExamLivePreviewState extends State<ExamLivePreview> {
  static const double pageWidth = 794;
  static const double pageHeight = 1123;
  static const double margin = 48;
  final _boundary = GlobalKey();
  late ExamPreviewController _controller;
  late bool _ownsController;
  Size _viewport = Size.zero;
  int _pageCount = 1;
  int _renderedPage = 0;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  void _attachController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ExamPreviewController();
    _controller.addListener(_onViewChanged);
  }

  void _onViewChanged() {
    if (mounted && _controller.visiblePage(_pageCount) != _renderedPage) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ExamLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onViewChanged);
      if (_ownsController) _controller.dispose();
      _attachController();
    }
    // Paper edits retain the current page; clamp it only after the new page
    // count is rendered, without notifying sibling views during their build.
    final active = _controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(active, _controller)) {
        active.goToPage(active.visiblePage(_pageCount), pageCount: _pageCount);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onViewChanged);
    if (_ownsController) _controller.dispose();
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
    var height = ExamPreviewHeader.heightFor(widget.paper);
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

    for (final line in examPaperBodyAsPlainText(widget.paper).split('\n')) {
      var remaining = line;
      while (true) {
        final h = measure(remaining);
        if (height + h <= available) {
          page.add(remaining);
          height += h;
          break;
        }
        if (page.isNotEmpty || (pages.isEmpty && height > 0)) {
          // The header may fill the first sheet even before any body text.
          pages.add(page);
          page = <String>[];
          height = 0;
          continue;
        }
        // A paragraph taller than a sheet must be split, including a long
        // unbroken word. Work in Unicode scalars to avoid splitting a surrogate.
        final characters = remaining.runes.toList();
        var low = 1;
        var high = characters.length;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          if (measure(String.fromCharCodes(characters.take(mid))) <= available) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        final candidate = String.fromCharCodes(characters.take(low));
        final wordBoundary = candidate.lastIndexOf(' ');
        final prefix = wordBoundary > 0 ? candidate.substring(0, wordBoundary) : candidate;
        pages.add(<String>[prefix]);
        remaining = remaining.substring(prefix.length).trimLeft();
        height = 0;
        if (remaining.isEmpty) break;
      }
    }
    if (page.isNotEmpty) pages.add(page);
    return pages.isEmpty ? <List<String>>[<String>[]] : pages;
  }

  Future<void> _sharePng(Uint8List bytes, String name) async {
    try {
      final result = await (widget.shareImage ?? ExamDocumentExporter.shareImage)(bytes, name);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّرت مشاركة الصورة: $error')));
    }
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    // Freeze the page number and file name before asynchronous rendering.
    final page = _controller.visiblePage(_pageCount);
    final name = examPaperFileName(
      widget.paper,
    ).replaceFirst(RegExp(r'\.docx$'), '-${page + 1}.png');
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final captured = await const ExamPageImageCapture().capture(
        logicalSize: boundary.size,
        render: (ratio) => boundary.toImage(pixelRatio: ratio),
      );
      final result = await (widget.exportImage ?? ExamDocumentExporter.exportImage)(
        captured.bytes,
        name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          action: !result.wasCancelled && !result.shared
              ? SnackBarAction(
                  label: 'مشاركة',
                  onPressed: () {
                    if (mounted) _sharePng(captured.bytes, name);
                  },
                )
              : null,
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر تصدير الصورة: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _setZoom(double value) =>
      _controller.setZoom(value, focalPoint: _viewport.center(Offset.zero));

  @override
  Widget build(BuildContext context) {
    final pages = _paginate();
    _pageCount = pages.length;
    final page = _controller.visiblePage(_pageCount);
    _renderedPage = page;
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
                onPressed: () => _setZoom(_controller.zoom / 1.25),
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                tooltip: 'تكبير المعاينة',
                onPressed: () => _setZoom(_controller.zoom * 1.25),
                icon: const Icon(Icons.zoom_in),
              ),
              TextButton(
                onPressed: () => _controller.fitWidth(
                  viewport: _viewport,
                  page: const Size(pageWidth, pageHeight),
                ),
                child: const Text('ملاءمة العرض'),
              ),
              if (widget.showFullscreenButton)
                IconButton(
                  tooltip: 'معاينة ملء الشاشة',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _exporting
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('معاينة الورقة الرسمية')),
                              body: ExamLivePreview(
                                paper: widget.paper,
                                exportImage: widget.exportImage,
                                shareImage: widget.shareImage,
                                controller: _controller,
                                showFullscreenButton: false,
                              ),
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
                  onPressed: !_exporting && page > 0
                      ? () => _controller.goToPage(page - 1, pageCount: _pageCount)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Text('${page + 1} / ${pages.length}'),
                IconButton(
                  tooltip: 'الصفحة التالية',
                  onPressed: !_exporting && page + 1 < pages.length
                      ? () => _controller.goToPage(page + 1, pageCount: _pageCount)
                      : null,
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
            builder: (context, constraints) {
              _viewport = constraints.biggest;
              return InteractiveViewer(
                transformationController: _controller.transformation,
                minScale: ExamPreviewController.minZoom,
                maxScale: ExamPreviewController.maxZoom,
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
              );
            },
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
  static const double _tableWidth = 500;
  static TextStyle _styleFor(ExamPaper paper) => TextStyle(
    fontFamily: 'Amiri',
    color: Colors.black,
    fontSize: paper.typography.headerFontSize * 4 / 3,
    height: 1.3,
    fontWeight: FontWeight.bold,
  );

  static double _textHeight(String text, double width, ExamPaper paper) {
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: _styleFor(paper)),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  static List<String> _headerTexts(ExamPaper paper) => <String>[
    'ادارة\n${paper.info.school}',
    '${paper.info.examTitleLine}\n${paper.info.yearLine}\nالتربية الفنية',
    'الاسم :\n${paper.info.classLine}\nالرقم الامتحاني :',
  ];

  static double _rowHeight(ExamPaper paper) {
    final texts = _headerTexts(paper);
    const weights = <int>[2693, 5245, 2977];
    return List<double>.generate(
      3,
      (i) => _textHeight(texts[i], 698 * weights[i] / 10915 - 6, paper) + 6,
    ).reduce((a, b) => a > b ? a : b);
  }

  /// Measure using the same constraints and fonts as the rendered header.
  /// Long labels and the maximum supported size cannot overflow a fixed box.
  static double heightFor(ExamPaper paper) {
    double cellHeight(String text) => _textHeight(text, _tableWidth / 5 - 7.4, paper) + 7.4;
    final labels = <String>[
      'رقم السؤال',
      'الدرجة رقما',
      'الدرجة كتابة',
      'اسم المصحح',
      'اسم المدقق',
    ];
    final heading = labels.map(cellHeight).reduce((a, b) => a > b ? a : b);
    return _rowHeight(paper) +
        heading +
        cellHeight('س1') * 6 +
        cellHeight('المجموع') +
        _textHeight('العملـــــي', _tableWidth - 7.4, paper) +
        7.4 +
        10;
  }

  final ExamPaper paper;
  @override
  Widget build(BuildContext context) {
    final info = paper.info;
    final headerStyle = _styleFor(paper);
    Widget cell(String text) => Padding(
      padding: const EdgeInsets.all(3),
      child: Text(text, style: headerStyle, textAlign: TextAlign.center),
    );
    TableRow scoreRow(String text) =>
        TableRow(children: <Widget>[cell(text), cell(''), cell(''), cell(''), cell('')]);
    return SizedBox(
      height: heightFor(paper),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: _rowHeight(paper),
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
              width: _tableWidth,
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
