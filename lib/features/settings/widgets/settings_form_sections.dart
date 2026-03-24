import 'package:flutter/material.dart';

import '../settings_section.dart';
import '../settings_types.dart';

class SettingsIntroCard extends StatelessWidget {
  const SettingsIntroCard({
    super.key,
    required this.colorScheme,
    required this.textTheme,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.tune_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Personalize Stepped',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update profile identity, appearance, and wishlist behavior.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return SettingsSection(
      title: 'Profile',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Traveler',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: homeBaseController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Home base',
              hintText: 'City or country',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: bioController,
            textInputAction: TextInputAction.done,
            maxLines: 3,
            minLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              hintText: 'Traveler and planner.',
              prefixIcon: Icon(Icons.menu_book_outlined),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }
}

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({
    super.key,
    required this.textTheme,
    required this.currentThemeMode,
    required this.onThemeChoiceChanged,
  });

  final TextTheme textTheme;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeChoice> onThemeChoiceChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Appearance',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Theme mode',
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              SegmentedButton<ThemeChoice>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<ThemeChoice>>[
                  ButtonSegment<ThemeChoice>(
                    value: ThemeChoice.system,
                    icon: Icon(Icons.settings_suggest_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment<ThemeChoice>(
                    value: ThemeChoice.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment<ThemeChoice>(
                    value: ThemeChoice.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: <ThemeChoice>{toThemeChoice(currentThemeMode)},
                onSelectionChanged: (selected) {
                  if (selected.isEmpty) {
                    return;
                  }
                  onThemeChoiceChanged(selected.first);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WishlistSettingsSection extends StatelessWidget {
  const WishlistSettingsSection({
    super.key,
    required this.confirmWishlistDelete,
    required this.showWishlistDates,
    required this.onConfirmWishlistDeleteChanged,
    required this.onShowWishlistDatesChanged,
  });

  final bool confirmWishlistDelete;
  final bool showWishlistDates;
  final ValueChanged<bool> onConfirmWishlistDeleteChanged;
  final ValueChanged<bool> onShowWishlistDatesChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Wishlist',
      children: <Widget>[
        SwitchListTile(
          value: confirmWishlistDelete,
          title: const Text('Confirm before delete'),
          subtitle: const Text(
            'Ask before removing wishlist items.',
          ),
          onChanged: onConfirmWishlistDeleteChanged,
        ),
        const Divider(height: 1),
        SwitchListTile(
          value: showWishlistDates,
          title: const Text('Show saved date'),
          subtitle: const Text(
            'Display when each wishlist item was added.',
          ),
          onChanged: onShowWishlistDatesChanged,
        ),
      ],
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
    return SettingsSection(
      title: 'Data',
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('Reset settings'),
          subtitle: const Text('Restore defaults for this screen.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onResetSettings,
        ),
      ],
    );
  }
}
