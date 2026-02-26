import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _homeBaseController = TextEditingController();
  final TextEditingController _geminiApiKeyController =
      TextEditingController();

  bool _didHydrate = false;
  bool _isHydrating = false;
  bool _isSaving = false;
  bool _showGeminiApiKey = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onDraftChanged);
    _homeBaseController.addListener(_onDraftChanged);
    _geminiApiKeyController.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onDraftChanged);
    _homeBaseController.removeListener(_onDraftChanged);
    _geminiApiKeyController.removeListener(_onDraftChanged);
    _nameController.dispose();
    _homeBaseController.dispose();
    _geminiApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(appPreferencesProvider);
    final currentPrefs = preferencesAsync.valueOrNull;
    if (currentPrefs != null && !_didHydrate) {
      _hydrate(currentPrefs);
    }

    final hasUnsavedChanges = currentPrefs != null &&
        _didHydrate &&
        (_nameController.text.trim() != currentPrefs.displayName ||
            _homeBaseController.text.trim() != currentPrefs.homeBase ||
            _geminiApiKeyController.text.trim() != currentPrefs.geminiApiKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: currentPrefs == null || _isSaving
                ? null
                : () => _saveProfileFields(currentPrefs),
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(hasUnsavedChanges ? 'Save' : 'Saved'),
          ),
        ],
      ),
      body: preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load settings: $error'),
          ),
        ),
        data: (prefs) {
          final notifier = ref.read(appPreferencesProvider.notifier);
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: <Widget>[
              Card(
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
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'Profile',
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: TextField(
                      controller: _nameController,
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
                      controller: _homeBaseController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Home base',
                        hintText: 'City or country',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
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
                        SegmentedButton<_ThemeChoice>(
                          showSelectedIcon: false,
                          segments: const <ButtonSegment<_ThemeChoice>>[
                            ButtonSegment<_ThemeChoice>(
                              value: _ThemeChoice.system,
                              icon: Icon(Icons.settings_suggest_outlined),
                              label: Text('System'),
                            ),
                            ButtonSegment<_ThemeChoice>(
                              value: _ThemeChoice.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment<_ThemeChoice>(
                              value: _ThemeChoice.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: <_ThemeChoice>{_toChoice(prefs.themeMode)},
                          onSelectionChanged: (selected) {
                            if (selected.isEmpty) {
                              return;
                            }
                            notifier.updateThemeMode(
                              _toThemeMode(selected.first),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'Wishlist',
                children: <Widget>[
                  SwitchListTile(
                    value: prefs.confirmWishlistDelete,
                    title: const Text('Confirm before delete'),
                    subtitle: const Text(
                      'Ask before removing wishlist items.',
                    ),
                    onChanged: (value) {
                      notifier.updateConfirmWishlistDelete(value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: prefs.showWishlistDates,
                    title: const Text('Show saved date'),
                    subtitle: const Text(
                      'Display when each wishlist item was added.',
                    ),
                    onChanged: (value) {
                      notifier.updateShowWishlistDates(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'AI Trip Planner',
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: TextField(
                      controller: _geminiApiKeyController,
                      obscureText: !_showGeminiApiKey,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Gemini API key',
                        hintText: 'Paste your Gemini API token',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          tooltip: _showGeminiApiKey ? 'Hide key' : 'Show key',
                          onPressed: () {
                            setState(() {
                              _showGeminiApiKey = !_showGeminiApiKey;
                            });
                          },
                          icon: Icon(
                            _showGeminiApiKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      'Used only for wishlist AI planning requests from this device.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Clear API key'),
                    subtitle: const Text('Remove the stored Gemini token.'),
                    enabled: _geminiApiKeyController.text.trim().isNotEmpty,
                    onTap: _geminiApiKeyController.text.trim().isEmpty
                        ? null
                        : () {
                            _geminiApiKeyController.clear();
                            setState(() {});
                          },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'Data',
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Reset settings'),
                    subtitle: const Text('Restore defaults for this screen.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _confirmResetDefaults,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _hydrate(AppPreferences prefs) {
    _isHydrating = true;
    _nameController.text = prefs.displayName;
    _homeBaseController.text = prefs.homeBase;
    _geminiApiKeyController.text = prefs.geminiApiKey;
    _didHydrate = true;
    _isHydrating = false;
  }

  Future<void> _saveProfileFields(AppPreferences current) async {
    final name = _nameController.text.trim();
    final homeBase = _homeBaseController.text.trim();
    final normalizedName =
        name.isEmpty ? AppPreferences.defaults.displayName : name;
    final hasNameChange = normalizedName != current.displayName;
    final hasHomeBaseChange = homeBase != current.homeBase;
    final geminiApiKey = _geminiApiKeyController.text.trim();
    final hasGeminiApiKeyChange = geminiApiKey != current.geminiApiKey;
    if (!hasNameChange && !hasHomeBaseChange && !hasGeminiApiKeyChange) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final notifier = ref.read(appPreferencesProvider.notifier);
    try {
      if (hasNameChange) {
        await notifier.updateDisplayName(normalizedName);
      }
      if (hasHomeBaseChange) {
        await notifier.updateHomeBase(homeBase);
      }
      if (hasGeminiApiKeyChange) {
        await notifier.updateGeminiApiKey(geminiApiKey);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _onDraftChanged() {
    if (_isHydrating) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmResetDefaults() async {
    final shouldReset = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Reset settings?'),
              content: const Text(
                'This will restore default theme and profile preferences.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldReset) {
      return;
    }

    await ref.read(appPreferencesProvider.notifier).resetToDefaults();
    if (!mounted) {
      return;
    }
    final resetState = ref.read(appPreferencesProvider).valueOrNull;
    if (resetState != null) {
      _nameController.text = resetState.displayName;
      _homeBaseController.text = resetState.homeBase;
      _geminiApiKeyController.text = resetState.geminiApiKey;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Defaults restored')),
    );
  }
}

enum _ThemeChoice {
  system,
  light,
  dark,
}

_ThemeChoice _toChoice(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => _ThemeChoice.light,
    ThemeMode.dark => _ThemeChoice.dark,
    ThemeMode.system => _ThemeChoice.system,
  };
}

ThemeMode _toThemeMode(_ThemeChoice choice) {
  return switch (choice) {
    _ThemeChoice.system => ThemeMode.system,
    _ThemeChoice.light => ThemeMode.light,
    _ThemeChoice.dark => ThemeMode.dark,
  };
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
