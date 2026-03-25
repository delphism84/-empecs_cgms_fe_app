import 'package:flutter/material.dart';

/// 앱 네비게이션 접근(봇/디버그용 포함)
/// - main.dart/MaterialApp이 이 키를 사용해야 한다.
/// - BleEmuServer가 이 키를 통해 라우팅을 강제로 전환할 수 있다.
class AppNav {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final ValueNotifier<String> currentRoute = ValueNotifier<String>('/');

  static final NavigatorObserver observer = _AppNavObserver();

  static String get route => currentRoute.value;

  static Future<bool> goNamed(String routeName, {bool replaceStack = false, Object? arguments}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return false;
    try {
      if (replaceStack) {
        nav.pushNamedAndRemoveUntil(routeName, (r) => false, arguments: arguments);
      } else {
        nav.pushNamed(routeName, arguments: arguments);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _AppNavObserver extends NavigatorObserver {
  String _name(Route<dynamic>? r) {
    final n = r?.settings.name;
    if (n != null && n.isNotEmpty) return n;
    return r?.runtimeType.toString() ?? '';
  }

  void _set(Route<dynamic>? r) {
    final n = _name(r);
    if (n.isNotEmpty) AppNav.currentRoute.value = n;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _set(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _set(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _set(previousRoute);
  }
}

