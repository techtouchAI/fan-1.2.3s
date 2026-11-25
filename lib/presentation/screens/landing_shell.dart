import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'index_screen.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'quiz_picker_screen.dart';

/// Responsive shell: navigation rail on Windows / tablets, navigation bar on
/// phones. Settings remain reachable from the rail and primary headers.
class LandingShell extends StatefulWidget {
  const LandingShell({super.key});

  @override
  State<LandingShell> createState() => _LandingShellState();
}

class _LandingShellState extends State<LandingShell> {
  int _index = 0;
  final Set<int> _visited = <int>{0};

  void _select(int value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = value;
      _visited.add(value);
    });
  }

  static const List<_Destination> _destinations = <_Destination>[
    _Destination('الرئيسية', Icons.home_outlined, Icons.home),
    _Destination('الفهرس', Icons.menu_book_outlined, Icons.menu_book),
    _Destination('البحث', Icons.search_outlined, Icons.search),
    _Destination('المفضلة', Icons.bookmark_border, Icons.bookmark),
    _Destination('الاختبار', Icons.quiz_outlined, Icons.quiz),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= AppLayout.railBreakpoint;
    final pages = <Widget>[
      const HomeScreen(),
      const IndexScreen(),
      const SearchScreen(),
      const FavoritesScreen(embedded: true),
      const QuizPickerScreen(),
    ];

    // Lazy mounting avoids focusing search and building hidden readers on launch;
    // visited destinations retain their scroll position and form state.
    final content = IndexedStack(
      index: _index,
      children: <Widget>[
        for (var i = 0; i < pages.length; i++)
          _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
      ],
    );

    if (useRail) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[_BrandMark(compact: true), SizedBox(height: 4), Text('مِرسم')],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _settingsButton(context),
                  ),
                ),
              ),
              destinations: _destinations
                  .map(
                    (_Destination item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: _destinations
            .map(
              (_Destination item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

Widget _settingsButton(BuildContext context) => IconButton(
  tooltip: 'الإعدادات',
  onPressed: () =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
  icon: const Icon(Icons.settings_outlined),
);

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Small identity mark (arch + colour dots) drawn with plain widgets.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 40 : 46,
          height: compact ? 40 : 46,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.palette, color: scheme.onPrimary, size: compact ? 22 : 26),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(width: AppSpacing.md),
          Text('مِرسم', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ],
    );
  }
}

/// Small brand header used on top of the primary pages.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showBrand = false,
    this.showSettings = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBrand;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 640;
    final useRail = width >= AppLayout.railBreakpoint;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge,
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              maxLines: narrow ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: narrow ? 13 : null),
            ),
          ),
      ],
    );

    final topRow = Row(
      children: <Widget>[
        if (showBrand) _BrandMark(compact: narrow),
        const Spacer(),
        ...actions,
        if (showSettings) _settingsButton(context),
        const TextScaleControls(),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        left: narrow ? AppSpacing.lg : AppSpacing.xl,
        right: narrow ? AppSpacing.lg : AppSpacing.xl,
        bottom: AppSpacing.md,
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                topRow,
                const SizedBox(height: AppSpacing.sm),
                titleBlock,
              ],
            )
          : Row(
              children: <Widget>[
                if (showBrand && !useRail) ...<Widget>[
                  _BrandMark(compact: width < 900),
                  const SizedBox(width: AppSpacing.lg),
                ],
                Expanded(child: titleBlock),
                ...actions,
                if (showSettings) _settingsButton(context),
                const SizedBox(width: AppSpacing.xs),
                const TextScaleControls(),
              ],
            ),
    );
  }
}

/// Reads the current state in a page that is hosted by the shell.
AppState pageState(BuildContext context) => AppScope.of(context);
