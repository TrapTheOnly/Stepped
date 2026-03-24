import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/seed/seed_data.dart';
import 'features/social/social_state.dart';
import 'features/settings/app_preferences.dart';
import 'routing/app_link_listener.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class SteppedAppBootstrap extends ConsumerWidget {
  const SteppedAppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    final router = ref.watch(appRouterProvider);
    final preferencesAsync = ref.watch(appPreferencesProvider);
    ref.watch(socialSyncBootstrapProvider);
    ref.watch(appLinkBootstrapProvider);
    final themeMode =
        preferencesAsync.valueOrNull?.themeMode ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'Stepped',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return startup.when(
          loading: () => const _LaunchScaffold(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _LaunchScaffold(
            child: Center(
              child: Text(
                'Startup failed: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (_) => child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _LaunchScaffold extends StatelessWidget {
  const _LaunchScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: child));
  }
}
