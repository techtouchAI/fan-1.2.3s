import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/dimens.dart';
import '../../../data/local/exam_document_exporter.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/services/exam_paper_formatter.dart';
import '../../services/exam_page_image_capture.dart';
import '../../state/exam_preview_controller.dart';

/// A paginated A4 reading surface driven by `examBodyBlocks` and
/// `examHeaderColumns` so typography, bold headings, branches, margins, score
/// table, and two-column footer match `ExamDocxBuilder`.
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
    if (mounted && _controller.visiblePage(_pageCount) != _renderedPage) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ExamLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onViewChanged);
      if (_ownsController) _controller.dispose();
      _attachController();
    }
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

  double get _lineHeightFactor =>
      (widget.paper.typography.lineSpacingPercent / 100).clamp(1.05, 2.2).toDouble();

  String get _fontFamily => widget.paper.typography.font.previewFamily;

  TextStyle _styleForRole(ExamBodyBlockRole role) {
    final typo = widget.paper.typography;
    final isHeading = role == ExamBodyBlockRole.sectionHeading;
    final isBold =
        isHeading ||
        role == ExamBodyBlockRole.questionHeading ||
        role == ExamBodyBlockRole.branchHeading ||
        role == ExamBodyBlockRole.paperNote ||
        role == ExamBodyBlockRole.footerSignoff;
    final ptSize = isHeading ? typo.headingFontSize : typo.bodyFontSize;
    return TextStyle(
      fontFamily: _fontFamily,
      color: Colors.black,
      fontSize: ptSize * 4 / 3,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      height: _lineHeightFactor,
    );
  }

  double _measureText(String text, TextStyle style, double maxWidth) {
    final safeWidth = math.max(40.0, maxWidth);
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: safeWidth);
    final h = painter.height;
    painter.dispose();
    return h;
  }

  double _measureBlock(ExamBodyBlock block, double contentWidth) {
    switch (block.role) {
      case ExamBodyBlockRole.spacer:
        return 8;
      case ExamBodyBlockRole.separatorRule:
        return 14;
      case ExamBodyBlockRole.footerSignoff:
        final style = _styleForRole(block.role);
        final leftW = contentWidth * 6000 / 10466 - 8;
        final rightW = contentWidth * 4466 / 10466 - 8;
        final h1 = _measureText(block.text, style, leftW);
        final h2 = _measureText(block.secondaryText, style, rightW);
        return math.max(h1, h2) + 8;
      default:
        final style = _styleForRole(block.role);
        return _measureText(block.text, style, contentWidth - block.indent) + 4;
    }
  }

  /// Paginates semantic blocks across A4 sheets, splitting oversized blocks at
  /// word boundaries when needed so zero words are ever clipped or lost.
  List<List<ExamBodyBlock>> _paginate() {
    final margins = widget.paper.margins;
    final contentWidth = pageWidth - margins.leftPx - margins.rightPx;
    final available = pageHeight - margins.topPx - margins.bottomPx - 28;
    final pages = <List<ExamBodyBlock>>[];
    var page = <ExamBodyBlock>[];
    var height = ExamPreviewHeader.heightFor(widget.paper, contentWidth: contentWidth);

    for (final ExamBodyBlock block in examBodyBlocks(widget.paper)) {
      if (block.role == ExamBodyBlockRole.spacer && page.isEmpty && height == 0) {
        continue;
      }
      if (block.role == ExamBodyBlockRole.footerSignoff ||
          block.role == ExamBodyBlockRole.separatorRule ||
          block.role == ExamBodyBlockRole.spacer) {
        final h = _measureBlock(block, contentWidth);
        if (height + h <= available) {
          page.add(block);
          height += h;
        } else {
          if (page.isNotEmpty || (pages.isEmpty && height > 0)) {
            pages.add(page);
            page = <ExamBodyBlock>[];
            height = 0;
          }
          page.add(block);
          height += h;
        }
        continue;
      }

      final style = _styleForRole(block.role);
      final lineMaxWidth = math.max(40.0, contentWidth - block.indent);
      var remaining = block.text;
      while (true) {
        final h = _measureText(remaining, style, lineMaxWidth) + 4;
        if (height + h <= available) {
          page.add(
            ExamBodyBlock(
              role: block.role,
              text: remaining,
              indent: block.indent,
            ),
          );
          height += h;
          break;
        }
        if (page.isNotEmpty || (pages.isEmpty && height > 0)) {
          pages.add(page);
          page = <ExamBodyBlock>[];
          height = 0;
          continue;
        }
        final characters = remaining.runes.toList();
        var low = 1;
        var high = characters.length;
        while (low < high) {
          final mid = (low + high + 1) ~/ 2;
          final slice = String.fromCharCodes(characters.take(mid));
          if (_measureText(slice, style, lineMaxWidth) + 4 <= available) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        final candidate = String.fromCharCodes(characters.take(low));
        final wordBoundary = candidate.lastIndexOf(' ');
        final prefix = wordBoundary > 0
            ? candidate.substring(0, wordBoundary)
            : candidate;
        pages.add(<ExamBodyBlock>[
          ExamBodyBlock(role: block.role, text: prefix, indent: block.indent),
        ]);
        remaining = remaining.substring(prefix.length).trimLeft();
        height = 0;
        if (remaining.isEmpty) break;
      }
    }
    if (page.isNotEmpty) pages.add(page);
    return pages.isEmpty ? <List<ExamBodyBlock>>[<ExamBodyBlock>[]] : pages;
  }

  Widget _buildBlockWidget(ExamBodyBlock block) {
    switch (block.role) {
      case ExamBodyBlockRole.spacer:
        return const SizedBox(height: 8);
      case ExamBodyBlockRole.separatorRule:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(color: Colors.black87, thickness: 1, height: 2),
        );
      case ExamBodyBlockRole.footerSignoff:
        final style = _styleForRole(block.role);
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 6000,
                child: Text(block.text, style: style, textAlign: TextAlign.center),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4466,
                child: Text(
                  block.secondaryText,
                  style: style,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      case ExamBodyBlockRole.paperNote:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            block.text,
            style: _styleForRole(block.role),
            textAlign: TextAlign.center,
          ),
        );
      default:
        return Padding(
          padding: EdgeInsetsDirectional.only(start: block.indent, bottom: 4),
          child: Text(
            block.text.isEmpty ? ' ' : block.text,
            style: _styleForRole(block.role),
          ),
        );
    }
  }

  Future<void> _sharePng(Uint8List bytes, String name) async {
    try {
      final result = await (widget.shareImage ?? ExamDocumentExporter.shareImage)(
        bytes,
        name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّرت مشاركة الصورة: $error')),
        );
      }
    }
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    final page = _controller.visiblePage(_pageCount);
    final name = examPaperFileName(
      widget.paper,
    ).replaceFirst(RegExp(r'\.docx$'), '-${page + 1}.png');
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر تصدير الصورة: $error')),
        );
      }
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
    final margins = widget.paper.margins;
    final contentWidth = pageWidth - margins.leftPx - margins.rightPx;
    final fontLabel = widget.paper.typography.font.label;

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'ورقة A4 رسمية • الخط: $fontLabel • مطابقة لتنسيق ملف Word وتصدير الصور.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          key: _boundary,
                          child: MediaQuery.withNoTextScaling(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Container(
                                width: pageWidth,
                                height: pageHeight,
                                padding: EdgeInsets.fromLTRB(
                                  margins.leftPx,
                                  margins.topPx,
                                  margins.rightPx,
                                  margins.bottomPx,
                                ),
                                color: Colors.white,
                                child: DefaultTextStyle(
                                  style: _styleForRole(ExamBodyBlockRole.itemLine),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      if (page == 0)
                                        ExamPreviewHeader(
                                          paper: widget.paper,
                                          contentWidth: contentWidth,
                                        ),
                                      for (final ExamBodyBlock block in pages[page])
                                        _buildBlockWidget(block),
                                      const Spacer(),
                                      Text(
                                        '${page + 1} / ${pages.length}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: _fontFamily,
                                          color: Colors.black87,
                                          fontSize: 12,
                                        ),
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
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Official three-column header and optional nine-row score table, synchronized
/// with `examHeaderColumns` and `ExamDocxBuilder`.
class ExamPreviewHeader extends StatelessWidget {
  const ExamPreviewHeader({
    super.key,
    required this.paper,
    this.contentWidth = defaultContentWidth,
  });

  static const double defaultContentWidth = 698;
  static const double _maxTableWidth = 500;

  final ExamPaper paper;
  final double contentWidth;

  static TextStyle _styleFor(ExamPaper paper) => TextStyle(
    fontFamily: paper.typography.font.previewFamily,
    color: Colors.black,
    fontSize: paper.typography.headerFontSize * 4 / 3,
    height: 1.3,
    fontWeight: FontWeight.bold,
  );

  static double _textHeight(String text, double width, ExamPaper paper) {
    final safeWidth = math.max(36.0, width);
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: _styleFor(paper)),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: safeWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  static List<String> _headerTexts(ExamPaper paper) {
    final cols = examHeaderColumns(paper);
    return <String>[cols.rightJoined, cols.centerJoined, cols.leftJoined];
  }

  static double _rowHeight(ExamPaper paper, double availableWidth) {
    final texts = _headerTexts(paper);
    const weights = <int>[2693, 5245, 2977];
    return List<double>.generate(
      3,
      (i) =>
          _textHeight(texts[i], availableWidth * weights[i] / 10915 - 6, paper) + 6,
    ).reduce((a, b) => a > b ? a : b);
  }

  static double heightFor(
    ExamPaper paper, {
    double contentWidth = defaultContentWidth,
  }) {
    final headerRow = _rowHeight(paper, contentWidth);
    if (!paper.headerConfig.showScoreTable) {
      return headerRow + 18;
    }
    final tableW = math.min(_maxTableWidth, contentWidth);
    double cellHeight(String text) => _textHeight(text, tableW / 5 - 7.4, paper) + 7.4;
    const labels = <String>[
      'رقم السؤال',
      'الدرجة رقما',
      'الدرجة كتابة',
      'اسم المصحح',
      'اسم المدقق',
    ];
    final heading = labels.map(cellHeight).reduce((a, b) => a > b ? a : b);
    return headerRow +
        heading +
        cellHeight('س1') * 6 +
        cellHeight('المجموع') +
        _textHeight('العملـــــي', tableW - 7.4, paper) +
        7.4 +
        24;
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = _styleFor(paper);
    final cols = examHeaderColumns(paper);
    final tableW = math.min(_maxTableWidth, contentWidth);

    Widget cell(String text, {TextAlign align = TextAlign.center}) => Padding(
      padding: const EdgeInsets.all(3),
      child: Text(text, style: headerStyle, textAlign: align),
    );

    TableRow scoreRow(String text) => TableRow(
      children: <Widget>[cell(text), cell(''), cell(''), cell(''), cell('')],
    );

    return SizedBox(
      height: heightFor(paper, contentWidth: contentWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: _rowHeight(paper, contentWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 2693, child: cell(cols.rightJoined)),
                Expanded(flex: 5245, child: cell(cols.centerJoined)),
                Expanded(
                  flex: 2977,
                  child: cell(cols.leftJoined, align: TextAlign.start),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.black87, thickness: 1, height: 10),
          if (paper.headerConfig.showScoreTable) ...<Widget>[
            Center(
              child: SizedBox(
                width: tableW,
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
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 0.7),
                      ),
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
            const Divider(color: Colors.black87, thickness: 1, height: 10),
          ] else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
