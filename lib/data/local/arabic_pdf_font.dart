import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Unicode-correct isolated forms at the pinned PDF/font integration boundary.
/// pdf 3.11.3's format-4 cmap aliases U+064A to U+FEEF (alef maksura)
/// instead of U+FEF1 (yeh). Families that omit redundant isolated codepoints
/// can therefore lose the yeh glyph or use the wrong glyph. Resolve single-
/// letter isolated compatibility forms to the SAME family's nominal glyph;
/// joined forms and multi-letter ligatures are never substituted or guessed.
class ArabicPdfFont extends pw.TtfFont {
  ArabicPdfFont(super.data);

  /// Unicode decomposition data (<isolated>, one base letter), FE80–FEF4.
  static const isolatedToBase = <int, int>{
    0xfe80: 0x0621, // hamza
    0xfe81: 0x0622, // alef with madda above
    0xfe83: 0x0623, // alef with hamza above
    0xfe85: 0x0624, // waw with hamza above
    0xfe87: 0x0625, // alef with hamza below
    0xfe89: 0x0626, // yeh with hamza above
    0xfe8d: 0x0627, // alef
    0xfe8f: 0x0628, // beh
    0xfe93: 0x0629, // teh marbuta
    0xfe95: 0x062a, // teh
    0xfe99: 0x062b, // theh
    0xfe9d: 0x062c, // jeem
    0xfea1: 0x062d, // hah
    0xfea5: 0x062e, // khah
    0xfea9: 0x062f, // dal
    0xfeab: 0x0630, // thal
    0xfead: 0x0631, // reh
    0xfeaf: 0x0632, // zain
    0xfeb1: 0x0633, // seen
    0xfeb5: 0x0634, // sheen
    0xfeb9: 0x0635, // sad
    0xfebd: 0x0636, // dad
    0xfec1: 0x0637, // tah
    0xfec5: 0x0638, // zah
    0xfec9: 0x0639, // ain
    0xfecd: 0x063a, // ghain
    0xfed1: 0x0641, // feh
    0xfed5: 0x0642, // qaf
    0xfed9: 0x0643, // kaf
    0xfedd: 0x0644, // lam
    0xfee1: 0x0645, // meem
    0xfee5: 0x0646, // noon
    0xfee9: 0x0647, // heh
    0xfeed: 0x0648, // waw
    0xfeef: 0x0649, // alef maksura
    0xfef1: 0x064a, // yeh
  };

  @override
  PdfFont buildFont(PdfDocument pdfDocument) {
    final result = PdfTtfFont(pdfDocument, data, protect: protect);
    final glyphs = result.font.charToGlyphIndexMap;
    for (final entry in isolatedToBase.entries) {
      final baseGlyph = glyphs[entry.value];
      if (baseGlyph != null && baseGlyph != 0) glyphs[entry.key] = baseGlyph;
    }
    return result;
  }
}
