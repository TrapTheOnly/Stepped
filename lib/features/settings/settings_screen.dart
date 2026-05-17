import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/editorial_overlay_page_shell.dart';
import '../../widgets/frosted_squircle.dart';
import '../auth/auth_controller.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';
import 'app_preferences.dart';
import 'settings_types.dart';
import 'widgets/ai_planner_settings_section.dart';
import 'widgets/settings_dialogs.dart';
import 'widgets/settings_form_sections.dart';

const _settingsBottomPadding = 56.0;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _geminiApiKeyController = TextEditingController();
  final TextEditingController _cloudApiBaseUrlController =
      TextEditingController();
  bool _didHydrate = false;
  bool _didHydratePrivacy = false;
  bool _isHydrating = false;
  bool _isSaving = false;
  bool _isSavingPrivacy = false;
  bool _showGeminiApiKey = false;
  AiSourceChoice _aiSourceChoice = AiSourceChoice.cloud;
  SocialPrivacySettings? _privacySettings;

  @override
  void initState() {
    super.initState();
    _geminiApiKeyController.addListener(_onDraftChanged);
    _cloudApiBaseUrlController.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    _geminiApiKeyController.removeListener(_onDraftChanged);
    _cloudApiBaseUrlController.removeListener(_onDraftChanged);
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
    final socialPrivacyAsync = ref.watch(socialPrivacyProvider);
    final currentPrefs = preferencesAsync.valueOrNull;
    if (currentPrefs != null && !_didHydrate) {
      _hydrate(currentPrefs);
    }
    final currentPrivacy = socialPrivacyAsync.valueOrNull;
    if (currentPrivacy != null && !_didHydratePrivacy) {
      _hydratePrivacy(currentPrivacy);
    }
    final privacyError = socialPrivacyAsync.hasError
        ? _messageForPrivacyError(socialPrivacyAsync.error)
        : null;

    final hasUnsavedChanges = currentPrefs != null &&
        _didHydrate &&
        (_geminiApiKeyController.text.trim() != currentPrefs.geminiApiKey ||
            _cloudApiBaseUrlController.text.trim() !=
                currentPrefs.cloudAiBaseUrl ||
            plannerSourceFromChoice(_aiSourceChoice) !=
                currentPrefs.aiPlannerSource);

    final colorScheme = Theme.of(context).colorScheme;

    return EditorialOverlayPageShell(
      background: const _SettingsAtmosphere(),
      backgroundColor: colorScheme.surface,
      topBar: _SettingsTopBar(
        canSave: currentPrefs != null && hasUnsavedChanges,
        isSaving: _isSaving,
        onBack: () => _popToProfile(context),
        onSave: currentPrefs == null || _isSaving
            ? null
            : () => _saveProfileFields(currentPrefs),
      ),
      bodyBuilder: (context, topContentInset, __) {
        return preferencesAsync.when(
          loading: () => _SettingsScrollView(
            topPadding: topContentInset,
            children: const <Widget>[
              _SettingsHorizontalPadding(
                child: SettingsStatusCard(
                  title: 'Loading settings',
                  showProgress: true,
                ),
              ),
            ],
          ),
          error: (error, _) => _SettingsScrollView(
            topPadding: topContentInset,
            children: <Widget>[
              _SettingsHorizontalPadding(
                child: SettingsStatusCard(
                  title: 'Failed to load settings: $error',
                ),
              ),
            ],
          ),
          data: (prefs) {
            final notifier = ref.read(appPreferencesProvider.notifier);
            return _SettingsScrollView(
              topPadding: topContentInset,
              children: <Widget>[
                _SettingsHorizontalPadding(
                  child: AppearanceSettingsSection(
                    currentThemeMode: prefs.themeMode,
                    onThemeChoiceChanged: (choice) {
                      notifier.updateThemeMode(
                        themeModeFromChoice(choice),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 34),
                _SettingsHorizontalPadding(
                  child: GeneralSettingsSection(
                    confirmWishlistDelete: prefs.confirmWishlistDelete,
                    confirmTripDelete: prefs.confirmTripDelete,
                    onConfirmWishlistDeleteChanged:
                        notifier.updateConfirmWishlistDelete,
                    onConfirmTripDeleteChanged:
                        notifier.updateConfirmTripDelete,
                  ),
                ),
                const SizedBox(height: 34),
                _SettingsHorizontalPadding(
                  child: WishlistSettingsSection(
                    showWishlistDates: prefs.showWishlistDates,
                    shareWishlistWithFriends:
                        _privacySettings?.shareWishlistWithFriends,
                    isSavingPrivacy:
                        socialPrivacyAsync.isLoading || _isSavingPrivacy,
                    privacyErrorMessage: privacyError,
                    onShowWishlistDatesChanged:
                        notifier.updateShowWishlistDates,
                    onShareWishlistChanged: _handleWishlistPrivacyChanged,
                  ),
                ),
                const SizedBox(height: 34),
                _SettingsHorizontalPadding(
                  child: AiPlannerSettingsSection(
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
                ),
                const SizedBox(height: 34),
                _SettingsHorizontalPadding(
                  child: DataSettingsSection(
                    onResetSettings: _confirmResetDefaults,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension _SettingsScreenActionMethods on _SettingsScreenState {
  void _hydrate(AppPreferences prefs) {
    _isHydrating = true;
    _geminiApiKeyController.text = prefs.geminiApiKey;
    _cloudApiBaseUrlController.text = prefs.cloudAiBaseUrl;
    _aiSourceChoice = toAiSourceChoice(prefs.aiPlannerSource);
    _didHydrate = true;
    _isHydrating = false;
  }

  void _hydratePrivacy(SocialPrivacySettings privacy) {
    _privacySettings = privacy;
    _didHydratePrivacy = true;
  }

  Future<void> _saveProfileFields(AppPreferences current) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
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
    if (!hasGeminiApiKeyChange &&
        !hasCloudApiBaseUrlChange &&
        !hasAiPlannerSourceChange) {
      return;
    }

    _applyState(() {
      _isSaving = true;
    });

    final notifier = ref.read(appPreferencesProvider.notifier);
    try {
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

  String _messageForPrivacyError(Object? error) {
    if (error is SocialApiException) {
      return error.message;
    }
    return 'Could not load privacy right now.';
  }

  Future<void> _handleWishlistPrivacyChanged(bool value) async {
    final session = ref.read(socialSessionProvider);
    final previousValue = _privacySettings?.shareWishlistWithFriends;
    if (session == null || previousValue == null) {
      return;
    }

    final refreshedToken =
        await ref.read(authControllerProvider).getFreshAccessToken(
              forceRefresh: true,
            );

    _applyState(() {
      _isSavingPrivacy = true;
      _privacySettings = _privacySettings?.copyWith(
        shareWishlistWithFriends: value,
        wishlistVisibility: value ? 'friends' : 'private',
      );
    });

    try {
      final updated = await ref.read(socialApiClientProvider).updateMyPrivacy(
            accessToken: refreshedToken ?? session.accessToken,
            shareWishlistWithFriends: value,
          );
      if (!mounted) {
        return;
      }
      _applyState(() {
        _privacySettings = updated;
        _didHydratePrivacy = true;
      });
      ref.invalidate(socialPrivacyProvider);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            updated.shareWishlistWithFriends
                ? 'Wishlist is now shared with friends'
                : 'Wishlist is now private',
          ),
        ),
      );
    } on SocialApiException catch (error) {
      if (!mounted) {
        return;
      }
      _applyState(() {
        _privacySettings = _privacySettings?.copyWith(
          shareWishlistWithFriends: previousValue,
          wishlistVisibility: previousValue ? 'friends' : 'private',
        );
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _applyState(() {
        _privacySettings = _privacySettings?.copyWith(
          shareWishlistWithFriends: previousValue,
          wishlistVisibility: previousValue ? 'friends' : 'private',
        );
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Could not update wishlist privacy right now.'),
        ),
      );
    } finally {
      if (mounted) {
        _applyState(() {
          _isSavingPrivacy = false;
        });
      }
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
      _geminiApiKeyController.text = resetState.geminiApiKey;
      _cloudApiBaseUrlController.text = resetState.cloudAiBaseUrl;
      _aiSourceChoice = toAiSourceChoice(resetState.aiPlannerSource);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Defaults restored')),
    );
  }

  void _popToProfile(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/profile');
  }
}

class _SettingsAtmosphere extends StatelessWidget {
  const _SettingsAtmosphere();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colorScheme.surface.withValues(alpha: 0.08),
            colorScheme.surface,
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -0.8),
            radius: 1.0,
            colors: <Color>[
              colorScheme.primary.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsScrollView extends StatelessWidget {
  const _SettingsScrollView({
    required this.children,
    this.topPadding = 0,
  });

  final List<Widget> children;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            0,
            topPadding,
            0,
            _settingsBottomPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _SettingsHorizontalPadding extends StatelessWidget {
  const _SettingsHorizontalPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class _SettingsTopBar extends StatelessWidget {
  const _SettingsTopBar({
    required this.canSave,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
  });

  final bool canSave;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Back',
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 24,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    letterSpacing: 0.8,
                  ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: canSave && !isSaving ? onSave : null,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                icon: isSaving
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurface,
                        ),
                      )
                    : Icon(
                        canSave
                            ? Icons.check_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                label: Text(canSave ? 'Save' : 'Saved'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsStatusCard extends StatelessWidget {
  const SettingsStatusCard({
    super.key,
    required this.title,
    this.showProgress = false,
  });

  final String title;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.14),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (showProgress) ...<Widget>[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 6),
            ),
          ],
        ],
      ),
    );
  }
}
