import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/settings/app_preferences.dart';
import 'frosted_squircle.dart';
import 'person_avatar.dart';

class SteppedTopBar extends ConsumerWidget {
  const SteppedTopBar({
    super.key,
    required this.onOpenSettings,
    this.onOpenProfile,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final authController = ref.watch(authControllerProvider);
    final preferences = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    final preferredDisplayName = preferences.displayName.trim();
    final displayName = preferredDisplayName.isNotEmpty
        ? preferredDisplayName
        : (authController.currentUser?.displayName.trim().isNotEmpty == true
            ? authController.currentUser!.displayName
            : AppPreferences.defaults.displayName);
    final profilePhotoUrl = authController.currentUser?.photoUrl;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 16,
      color: colorScheme.surface.withValues(alpha: 0.54),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: SizedBox(
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onOpenSettings,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Settings',
                icon: Icon(
                  Icons.settings_outlined,
                  size: 24,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              'STEPPED',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    letterSpacing: 2.8,
                    fontSize: 25,
                  ),
            ),
            if (onOpenProfile != null)
              Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: 'Profile',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpenProfile,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: PersonAvatar(
                          displayName: displayName,
                          photoUrl: profilePhotoUrl,
                          radius: 16,
                          backgroundColor:
                              colorScheme.primaryContainer.withValues(
                            alpha: 0.92,
                          ),
                          foregroundColor: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
