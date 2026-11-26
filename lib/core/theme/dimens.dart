/// Spacing, border radii, and responsive layout breakpoints.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 36;
  static const double xxxl = 48;
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
}

abstract final class AppLayout {
  /// Switch from bottom NavigationBar to desktop/tablet NavigationRail.
  static const double railBreakpoint = 840;

  /// Two-column wide layout threshold.
  static const double wideBreakpoint = 1040;

  /// Comfortable reading column width on wide Windows monitors.
  static const double readingMaxWidth = 920;

  /// Max width for dashboard grids.
  static const double pageMaxWidth = 1140;
}
