// lib/utils/analytics_observer.dart
import 'package:flutter/widgets.dart';
import 'package:servana/utils/analytics.dart';

class ScreenTrackerObserver extends NavigatorObserver {
  // no const constructor
  ScreenTrackerObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name ?? route.runtimeType.toString();
    Analytics.log('view_screen', params: {'screen': name});
  }
}
