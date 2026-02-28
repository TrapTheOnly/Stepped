import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences.dart';
import 'settings_types.dart';
import 'widgets/ai_planner_settings_section.dart';
import 'widgets/settings_dialogs.dart';
import 'widgets/settings_form_sections.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _homeBaseController = TextEditingController();
  final TextEditingController _geminiApiKeyController = TextEditingController();
  final TextEditingController _cloudApiBaseUrlController =
      TextEditingController();
  bool _didHydrate = false;
  bool _isHydrating = false;
  bool _isSaving = false;
  bool _showGeminiApiKey = false;
  AiSourceChoice _aiSourceChoice = AiSourceChoice.cloud;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onDraftChanged);
    _homeBaseController.addListener(_onDraftChanged);
    _geminiApiKeyController.addListener(_onDraftChanged);
    _cloudApiBaseUrlController.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onDraftChanged);
    _homeBaseController.removeListener(_onDraftChanged);
    _geminiApiKeyController.removeListener(_onDraftChanged);
    _cloudApiBaseUrlController.removeListener(_onDraftChanged);
    _nameController.dispose();
    _homeBaseController.dispose();
    _geminiApiKeyController.dispose();
    _cloudApiBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildScreenContent(context);
  }

  void _applyState(VoidCallback updater) {
    if (!mounted) {
      return;
    }
    setState(updater);
  }
}

extension _SettingsScreenBuildMethods on _SettingsScreenState {
  Widget _buildScreenContent(BuildContext context) {
    final preferencesAsync = ref.watch(appPreferencesProvider);
    final currentPrefs = preferencesAsync.valueOrNull;
    if (currentPrefs != null && !_didHydrate) {
      _hydrate(currentPrefs);
    }

    final hasUnsavedChanges = currentPrefs != null &&
        _didHydrate &&
        (_nameController.text.trim() != currentPrefs.displayName ||
            _homeBaseController.text.trim() != currentPrefs.homeBase ||
            _geminiApiKeyController.text.trim() != currentPrefs.geminiApiKey ||
            _cloudApiBaseUrlController.text.trim() !=
                currentPrefs.cloudAiBaseUrl ||
            plannerSourceFromChoice(_aiSourceChoice) !=
                currentPrefs.aiPlannerSource);

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
              SettingsIntroCard(
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 14),
              ProfileSettingsSection(
                nameController: _nameController,
                homeBaseController: _homeBaseController,
              ),
              const SizedBox(height: 14),
              AppearanceSettingsSection(
                textTheme: textTheme,
                currentThemeMode: prefs.themeMode,
                onThemeChoiceChanged: (choice) {
                  notifier.updateThemeMode(themeModeFromChoice(choice));
                },
              ),
              const SizedBox(height: 14),
              WishlistSettingsSection(
                confirmWishlistDelete: prefs.confirmWishlistDelete,
                showWishlistDates: prefs.showWishlistDates,
                onConfirmWishlistDeleteChanged:
                    notifier.updateConfirmWishlistDelete,
                onShowWishlistDatesChanged: notifier.updateShowWishlistDates,
              ),
              const SizedBox(height: 14),
              AiPlannerSettingsSection(
                textTheme: textTheme,
                colorScheme: colorScheme,
                aiSourceChoice: _aiSourceChoice,
                cloudApiBaseUrlController: _cloudApiBaseUrlController,
                geminiApiKeyController: _geminiApiKeyController,
                showGeminiApiKey: _showGeminiApiKey,
                onAiSourceChanged: (value) {
                  _applyState(() {
                    _aiSourceChoice = value;
                  });
                },
                onToggleGeminiApiKeyVisibility: () {
                  _applyState(() {
                    _showGeminiApiKey = !_showGeminiApiKey;
                  });
                },
                onClearGeminiApiKey: () {
                  _geminiApiKeyController.clear();
                  _applyState(() {});
                },
              ),
              const SizedBox(height: 14),
              DataSettingsSection(
                onResetSettings: _confirmResetDefaults,
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _SettingsScreenActionMethods on _SettingsScreenState {
  void _hydrate(AppPreferences prefs) {
    _isHydrating = true;
    _nameController.text = prefs.displayName;
    _homeBaseController.text = prefs.homeBase;
    _geminiApiKeyController.text = prefs.geminiApiKey;
    _cloudApiBaseUrlController.text = prefs.cloudAiBaseUrl;
    _aiSourceChoice = toAiSourceChoice(prefs.aiPlannerSource);
    _didHydrate = true;
    _isHydrating = false;
  }

  Future<void> _saveProfileFields(AppPreferences current) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = _nameController.text.trim();
    final homeBase = _homeBaseController.text.trim();
    final normalizedName =
        name.isEmpty ? AppPreferences.defaults.displayName : name;
    final hasNameChange = normalizedName != current.displayName;
    final hasHomeBaseChange = homeBase != current.homeBase;
    final geminiApiKey = _geminiApiKeyController.text.trim();
    final hasGeminiApiKeyChange = geminiApiKey != current.geminiApiKey;
    final cloudApiBaseUrl = _cloudApiBaseUrlController.text.trim();
    final normalizedCloudApiBaseUrl = cloudApiBaseUrl.isEmpty
        ? AppPreferences.defaults.cloudAiBaseUrl
        : cloudApiBaseUrl;
    final hasCloudApiBaseUrlChange =
        normalizedCloudApiBaseUrl != current.cloudAiBaseUrl;
    final aiPlannerSource = plannerSourceFromChoice(_aiSourceChoice);
    final hasAiPlannerSourceChange = aiPlannerSource != current.aiPlannerSource;
    if (!hasNameChange &&
        !hasHomeBaseChange &&
        !hasGeminiApiKeyChange &&
        !hasCloudApiBaseUrlChange &&
        !hasAiPlannerSourceChange) {
      return;
    }

    _applyState(() {
      _isSaving = true;
    });

    final notifier = ref.read(appPreferencesProvider.notifier);
    try {
      if (hasNameChange) {
        await notifier.updateDisplayName(normalizedName);
        if (!mounted) {
          return;
        }
      }
      if (hasHomeBaseChange) {
        await notifier.updateHomeBase(homeBase);
        if (!mounted) {
          return;
        }
      }
      if (hasGeminiApiKeyChange) {
        await notifier.updateGeminiApiKey(geminiApiKey);
        if (!mounted) {
          return;
        }
      }
      if (hasCloudApiBaseUrlChange) {
        await notifier.updateCloudAiBaseUrl(normalizedCloudApiBaseUrl);
        if (!mounted) {
          return;
        }
      }
      if (hasAiPlannerSourceChange) {
        await notifier.updateAiPlannerSource(aiPlannerSource);
        if (!mounted) {
          return;
        }
      }
      if (mounted) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } finally {
      if (mounted) {
        _applyState(() {
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
      _applyState(() {});
    }
  }

  Future<void> _confirmResetDefaults() async {
    final shouldReset = await showResetSettingsDialog(context);

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
      _cloudApiBaseUrlController.text = resetState.cloudAiBaseUrl;
      _aiSourceChoice = toAiSourceChoice(resetState.aiPlannerSource);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Defaults restored')),
    );
  }
}
