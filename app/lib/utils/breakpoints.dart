import 'package:flutter/widgets.dart';

/// Width below which the app switches to its phone layout.
///
/// Below this the 256px [Sidebar] is replaced by a bottom navigation bar,
/// screen chrome collapses into app bars, and multi-column rows stack.
const double kMobileBreakpoint = 700;

bool isMobileWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kMobileBreakpoint;
