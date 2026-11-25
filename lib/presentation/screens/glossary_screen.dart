import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import 'unit_screen.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _partFilter = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final normQuery = normalizeArabic(_query);

    final filtered = state.visibleGlossary
        .where((term) {
          if (_partFilter != 'all' && term.unitId != _partFilter) {
            return false;
          }
          if (normQuery.isEmpty) {
            return true;
          }
          final hay = normalizeArabic('${term.term} ${term.definition}');
          return hay.contains(normQuery);
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المصطلحات الفنية'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'تعريفات مختصرة للمصطلحات الفنية، مع رابط إلى الوحدة التي ورد فيها كل مصطلح.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث في مفردات المعجم (بدون تشكيل)...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('جميع الوحدات'),
                      selected: _partFilter == 'all',
                      onSelected: (_) => setState(() => _partFilter = 'all'),
                    ),
                    for (final unit in state.visibleUnits.where(
                      (unit) => state.visibleGlossary.any((term) => term.unitId == unit.id),
                    ))
                      ChoiceChip(
                        label: Text(unit.displayTitle),
                        selected: _partFilter == unit.id,
                        onSelected: (_) => setState(() => _partFilter = unit.id),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.translate_rounded,
                    title: 'لا توجد مفردة مطابقة',
                    message: 'جرّب كتابة الجذر أو جزء من الكلمة.',
                  )
                else
                  for (final term in filtered)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(term.term, style: theme.textTheme.titleMedium),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(term.definition, style: theme.textTheme.bodyMedium),
                            Text(
                              state.library.unitById(term.unitId)?.displayTitle ?? '',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => UnitScreen(unitId: term.unitId)),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
