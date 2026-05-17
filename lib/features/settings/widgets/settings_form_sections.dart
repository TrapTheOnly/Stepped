import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';
import '../settings_types.dart';

class SettingsSectionShell extends StatelessWidget {
  const SettingsSectionShell({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class SettingsEditorialCard extends StatelessWidget {
  const SettingsEditorialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.12),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: padding,
      child: child,
    );
  }
}

class ProfileSettingsSection extends StatelessWidget {
  const ProfileSettingsSection({
    super.key,
    required this.nameController,
    required this.homeBaseController,
    required this.bioController,
  });

  final TextEditingController nameController;
  final TextEditingController homeBaseController;
  final TextEditingController bioController;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionShell(
      title: 'Profile',
      child: SettingsEditorialCard(
        child: Column(
          children: <Widget>[
            _SettingsTextField(
              controller: nameController,
              label: 'Display name',
              hintText: 'Traveler',
              icon: Icons.person_outline,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _SettingsTextField(
              controller: homeBaseController,
              label: 'Home base',
              hintText: 'City or country',
              icon: Icons.home_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _SettingsTextField(
              controller: bioController,
              label: 'Bio',
              hintText: 'Traveler and planner',
              icon: Icons.menu_book_outlined,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChoiceChanged,
  });

  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeChoice> onThemeChoiceChanged;

  @override
  Widget build(BuildContext context) {
    final selected = toThemeChoice(currentThemeMode);
    return SettingsSectionShell(
      title: 'Appearance',
      child: SettingsEditorialCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: _ThemeModeChip(
                label: 'Auto',
                icon: Icons.settings_suggest_outlined,
                selected: selected == ThemeChoice.system,
                onTap: () => onThemeChoiceChanged(ThemeChoice.system),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ThemeModeChip(
                label: 'Light',
                icon: Icons.light_mode_outlined,
                selected: selected == ThemeChoice.light,
                onTap: () => onThemeChoiceChanged(ThemeChoice.light),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ThemeModeChip(
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
                selected: selected == ThemeChoice.dark,
                onTap: () => onThemeChoiceChanged(ThemeChoice.dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({
    super.key,
    required this.confirmWishlistDelete,
    required this.confirmTripDelete,
    required this.onConfirmWishlistDeleteChanged,
    required this.onConfirmTripDeleteChanged,
  });

  final bool confirmWishlistDelete;
  final bool confirmTripDelete;
  final ValueChanged<bool> onConfirmWishlistDeleteChanged;
  final ValueChanged<bool> onConfirmTripDeleteChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionShell(
      title: 'General',
      child: SettingsEditorialCard(
        child: Column(
          children: <Widget>[
            _SettingsSwitchTile(
              value: confirmWishlistDelete,
              onChanged: onConfirmWishlistDeleteChanged,
              icon: Icons.bookmark_remove_outlined,
              title: 'Confirm wishlist delete',
            ),
            const SizedBox(height: 12),
            _SettingsSwitchTile(
              value: confirmTripDelete,
              onChanged: onConfirmTripDeleteChanged,
              icon: Icons.delete_outline_rounded,
              title: 'Confirm trip delete',
            ),
          ],
        ),
      ),
    );
  }
}

class WishlistSettingsSection extends StatelessWidget {
  const WishlistSettingsSection({
    super.key,
    required this.showWishlistDates,
    required this.shareWishlistWithFriends,
    required this.isSavingPrivacy,
    required this.onShowWishlistDatesChanged,
    required this.onShareWishlistChanged,
    this.privacyErrorMessage,
  });

  final bool showWishlistDates;
  final bool? shareWishlistWithFriends;
  final bool isSavingPrivacy;
  final ValueChanged<bool> onShowWishlistDatesChanged;
  final ValueChanged<bool>? onShareWishlistChanged;
  final String? privacyErrorMessage;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionShell(
      title: 'Wishlist',
      child: SettingsEditorialCard(
        child: Column(
          children: <Widget>[
            _SettingsSwitchTile(
              value: showWishlistDates,
              onChanged: onShowWishlistDatesChanged,
              icon: Icons.event_note_rounded,
              title: 'Show saved date',
            ),
            const SizedBox(height: 12),
            _SettingsSwitchTile(
              value: shareWishlistWithFriends ?? false,
              onChanged: shareWishlistWithFriends == null || isSavingPrivacy
                  ? null
                  : onShareWishlistChanged,
              icon: isSavingPrivacy
                  ? Icons.sync_rounded
                  : Icons.lock_outline_rounded,
              title: 'Share with friends',
              isLoading: isSavingPrivacy,
            ),
            if (privacyErrorMessage != null &&
                privacyErrorMessage!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              _StatusChip(message: privacyErrorMessage!.trim()),
            ],
          ],
        ),
      ),
    );
  }
}

class DataSettingsSection extends StatelessWidget {
  const DataSettingsSection({
    super.key,
    required this.onResetSettings,
  });

  final VoidCallback onResetSettings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SettingsSectionShell(
      title: 'Data',
      child: SettingsEditorialCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onResetSettings,
            borderRadius: BorderRadius.circular(26),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.pressed)
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      shape: squircleShape(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.restart_alt_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Reset settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      maxLines: 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.30),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  const _ThemeModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.pressed)
              ? colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: ShapeDecoration(
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.90)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.30),
            shape: squircleShape(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    this.isLoading = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final String title;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
        shape: squircleShape(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colorScheme.surface.withValues(alpha: 0.66),
                shape: squircleShape(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(
                        icon,
                        color: colorScheme.primary,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        shape: squircleShape(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
