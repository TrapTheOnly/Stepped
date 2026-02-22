import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/seed/seed_data.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class SteppedAppBootstrap extends ConsumerWidget {
  const SteppedAppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final fallbackLight = ColorScheme.fromSeed(seedColor: Colors.teal);
        final fallbackDark = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        );

        final lightScheme = (lightDynamic ?? fallbackLight).harmonized();
        final darkScheme = (darkDynamic ?? fallbackDark).harmonized();

        return MaterialApp.router(
          title: 'Stepped',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(lightScheme),
          darkTheme: AppTheme.dark(darkScheme),
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
