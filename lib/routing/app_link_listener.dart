import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

final appLinkBootstrapProvider = Provider<void>((ref) {
  final router = ref.watch(appRouterProvider);
  final listener = _AppLinkListener(router);
  ref.onDispose(listener.dispose);
  unawaited(listener.start());
});

class _AppLinkListener {
  _AppLinkListener(this.router);

  static const String _appLinkHost = 'app.stepped.world';
  static const String _customScheme = 'stepped';

  final GoRouter router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _lastHandledRoute;

  Future<void> start() async {
    final initialLink = await _appLinks.getInitialLink();
    _handleUri(initialLink);

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('App link listener error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void _handleUri(Uri? uri) {
    if (uri == null) {
      return;
    }

    final route = _routeForUri(uri);
    if (route == null || route == _lastHandledRoute) {
      return;
    }

    _lastHandledRoute = route;
    router.go(route);
  }

  String? _routeForUri(Uri uri) {
    final segments = _friendInviteSegmentsForUri(uri);
    if (segments.length < 3) {
      return null;
    }

    final isFriendsInvite =
        segments[0].toLowerCase() == 'friends' &&
        segments[1].toLowerCase() == 'add';
    if (!isFriendsInvite) {
      return null;
    }

    final token = segments[2].trim();
    if (token.isEmpty) {
      return null;
    }

    return '/friends/add/$token';
  }

  List<String> _friendInviteSegmentsForUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') {
      if (uri.host.toLowerCase() != _appLinkHost) {
        return const <String>[];
      }
      return uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    }

    if (scheme == _customScheme) {
      return <String>[
        if (uri.host.isNotEmpty) uri.host,
        ...uri.pathSegments.where((segment) => segment.isNotEmpty),
      ];
    }

    return const <String>[];
  }

  void dispose() {
    _subscription?.cancel();
  }
}
