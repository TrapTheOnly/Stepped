import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/frosted_squircle.dart';
import '../auth/auth_controller.dart';
import '../settings/app_preferences.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';
import 'widgets/profile_summary_widgets.dart';

const _profileTopOverlayClearance = 114.0;
const _profileBottomPadding = 56.0;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _homeBaseController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  String? _draftFingerprint;
  String? _draftPhotoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _homeBaseController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visitedAsync = ref.watch(visitedCountProvider);
    final tripsAsync = ref.watch(tripsStreamProvider);
    final wishlistAsync = ref.watch(wishlistStreamProvider);
    final preferencesAsync = ref.watch(appPreferencesProvider);
    final socialMeAsync = ref.watch(socialMeProvider);
    final authController = ref.watch(authControllerProvider);
    final authUser = authController.currentUser;
    final preferences = preferencesAsync.valueOrNull ?? AppPreferences.defaults;
    final remoteProfile = socialMeAsync.valueOrNull?.profile;

    final resolvedDisplayName = _resolveDisplayName(
      authUserDisplayName: authUser?.displayName,
      localDisplayName: preferences.displayName,
      remoteDisplayName: remoteProfile?.displayName,
    );
    final resolvedHomeBase = _resolveProfileText(
      remoteValue: remoteProfile?.homeBase,
      localValue: preferences.homeBase,
    );
    final resolvedBio = _resolveProfileText(
      remoteValue: remoteProfile?.bio,
      localValue: preferences.bio,
    );
    final resolvedPhotoUrl = _resolvePhotoUrl(
      authPhotoUrl: authUser?.photoUrl,
      remotePhotoUrl: remoteProfile?.photoUrl,
    );
    final email = authUser?.email.trim() ?? '';

    _hydrateDrafts(
      displayName: resolvedDisplayName,
      homeBase: resolvedHomeBase,
      bio: resolvedBio,
      photoUrl: resolvedPhotoUrl,
    );

    final visited = visitedAsync.valueOrNull ?? 0;
    final trips = tripsAsync.valueOrNull ?? const <TripRecord>[];
    final wishlistItems =
        wishlistAsync.valueOrNull ?? const <WishlistItemRecord>[];
    final colorScheme = Theme.of(context).colorScheme;
    final hasPasswordProvider = authController.hasPasswordProvider;
    final hasUnsavedChanges = _isEditing &&
        (_hasProfileDraftChanges(
              displayName: resolvedDisplayName,
              homeBase: resolvedHomeBase,
              bio: resolvedBio,
              photoUrl: resolvedPhotoUrl,
            ) ||
            _hasPasswordDraftChanges());

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: ColoredBox(
        color: colorScheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(child: _ProfileAtmosphere()),
            ),
            Positioned.fill(
              child: _ProfileScrollView(
                children: <Widget>[
                  const SizedBox(height: _profileTopOverlayClearance),
                  _ProfileHorizontalPadding(
                    child: ProfileIdentityCard(
                      displayName: _isEditing
                          ? _normalizedDisplayName()
                          : resolvedDisplayName,
                      email: email,
                      homeBase: _isEditing
                          ? _homeBaseController.text.trim()
                          : resolvedHomeBase,
                      bio: _isEditing ? _bioController.text.trim() : resolvedBio,
                      photoUrl: _isEditing ? _draftPhotoUrl : resolvedPhotoUrl,
                      isEditing: _isEditing,
                      nameController: _nameController,
                      homeBaseController: _homeBaseController,
                      bioController: _bioController,
                      onPhotoTap: _pickProfilePhoto,
                      photoUploadLabel: 'Upload photo',
                      onProfileChanged: _handleDraftUpdated,
                    ),
                  ),
                  if (!_isEditing) ...<Widget>[
                    const SizedBox(height: 18),
                    _ProfileHorizontalPadding(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: ProfileStatCard(
                              label: 'Countries',
                              value: visitedAsync.isLoading ? '...' : '$visited',
                              icon: Icons.public_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ProfileStatCard(
                              label: 'Trips',
                              value: tripsAsync.isLoading
                                  ? '...'
                                  : '${trips.length}',
                              icon: Icons.flight_takeoff_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ProfileStatCard(
                              label: 'Wishlist',
                              value: wishlistAsync.isLoading
                                  ? '...'
                                  : '${wishlistItems.length}',
                              icon: Icons.favorite_outline_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_isEditing) ...<Widget>[
                    const SizedBox(height: 18),
                    _ProfileHorizontalPadding(
                      child: _PasswordCard(
                        hasPasswordProvider: hasPasswordProvider,
                        currentPasswordController: _currentPasswordController,
                        newPasswordController: _newPasswordController,
                        confirmPasswordController: _confirmPasswordController,
                        onChanged: _handleDraftUpdated,
                      ),
                    ),
                  ],
                  if (!_isEditing) ...<Widget>[
                    const SizedBox(height: 18),
                    _ProfileHorizontalPadding(
                      child: ProfileActionTile(
                        icon: Icons.tune_rounded,
                        title: 'Settings',
                        subtitle: 'Appearance, privacy, and planner behavior.',
                        onTap: () => context.push('/profile/settings'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileHorizontalPadding(
                      child: ProfileActionTile(
                        icon: Icons.logout_rounded,
                        title: authController.isBusy ? 'Signing out' : 'Sign out',
                        subtitle: 'Return to the auth screen for this device.',
                        emphasis: true,
                        onTap: authController.isBusy
                            ? null
                            : () async {
                                try {
                                  await ref.read(authControllerProvider).signOut();
                                } on AuthException catch (error) {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.message)),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _ProfileTopBar(
                    isEditing: _isEditing,
                    isSaving: _isSaving,
                    canSave: hasUnsavedChanges,
                    onBack: () => _handleBack(context),
                    onEditOrSave: _isEditing ? _saveProfile : _enterEditMode,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hydrateDrafts({
    required String displayName,
    required String homeBase,
    required String bio,
    required String? photoUrl,
  }) {
    final fingerprint = '$displayName|$homeBase|$bio|${photoUrl ?? ''}';
    if (_draftFingerprint == fingerprint || _isEditing) {
      return;
    }

    _draftFingerprint = fingerprint;
    _nameController.text = displayName;
    _homeBaseController.text = homeBase;
    _bioController.text = bio;
    _draftPhotoUrl = photoUrl;
  }

  String _resolveDisplayName({
    required String? authUserDisplayName,
    required String localDisplayName,
    required String? remoteDisplayName,
  }) {
    final remote = remoteDisplayName?.trim();
    if (remote != null &&
        remote.isNotEmpty &&
        remote != AppPreferences.defaults.displayName) {
      return remote;
    }

    final auth = authUserDisplayName?.trim();
    if (auth != null && auth.isNotEmpty) {
      return auth;
    }

    final local = localDisplayName.trim();
    if (local.isNotEmpty) {
      return local;
    }
    return AppPreferences.defaults.displayName;
  }

  String _resolveProfileText({
    required String? remoteValue,
    required String localValue,
  }) {
    final remote = remoteValue?.trim();
    if (remote != null && remote.isNotEmpty) {
      return remote;
    }
    return localValue.trim();
  }

  String? _resolvePhotoUrl({
    required String? authPhotoUrl,
    required String? remotePhotoUrl,
  }) {
    final auth = authPhotoUrl?.trim();
    if (auth != null && auth.isNotEmpty) {
      return auth;
    }
    final remote = remotePhotoUrl?.trim();
    if (remote != null && remote.isNotEmpty) {
      return remote;
    }
    return null;
  }

  bool _hasProfileDraftChanges({
    required String displayName,
    required String homeBase,
    required String bio,
    required String? photoUrl,
  }) {
    return _normalizedDisplayName() != displayName ||
        _homeBaseController.text.trim() != homeBase ||
        _bioController.text.trim() != bio ||
        _normalizedPhotoUrl() != (photoUrl?.trim().isNotEmpty == true ? photoUrl!.trim() : null);
  }

  bool _hasPasswordDraftChanges() {
    return _currentPasswordController.text.trim().isNotEmpty ||
        _newPasswordController.text.trim().isNotEmpty ||
        _confirmPasswordController.text.trim().isNotEmpty;
  }

  String _normalizedDisplayName() {
    final normalized = _nameController.text.trim();
    return normalized.isEmpty ? AppPreferences.defaults.displayName : normalized;
  }

  String? _normalizedPhotoUrl() {
    final normalized = _draftPhotoUrl?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _enterEditMode() {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isEditing = true;
    });
  }

  void _handleDraftUpdated() {
    if (!mounted || !_isEditing) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleBack(BuildContext context) async {
    if (_isEditing && !_isSaving) {
      setState(() {
        _isEditing = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _draftFingerprint = null;
      });
      return;
    }

    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  Future<void> _saveProfile() async {
    if (_isSaving) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final authController = ref.read(authControllerProvider);
    final session = ref.read(socialSessionProvider);
    final displayName = _normalizedDisplayName();
    final homeBase = _homeBaseController.text.trim();
    final bio = _bioController.text.trim();
    final photoUrl = _normalizedPhotoUrl();
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (displayName.length < 2) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Use at least 2 characters for your username.'),
        ),
      );
      return;
    }

    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
      if (newPassword != confirmPassword) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('New password and confirmation must match.')),
        );
        return;
      }
      if (newPassword.length < 10) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Password should be at least 10 characters.'),
          ),
        );
        return;
      }
      if (authController.hasPasswordProvider && currentPassword.isEmpty) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Enter your current password to change it.'),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final preferencesNotifier = ref.read(appPreferencesProvider.notifier);
      await authController.updateAccountProfile(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      await preferencesNotifier.hydrateProfileCache(
        displayName: displayName,
        homeBase: homeBase,
        bio: bio,
      );

      if (session != null) {
        final accessToken =
            await authController.getFreshAccessToken(forceRefresh: true);
        final profile = SocialProfileSnapshot(
          displayName: displayName,
          photoUrl: photoUrl ?? authController.currentUser?.photoUrl,
          homeBase: homeBase,
          bio: bio,
        );
        await ref.read(socialApiClientProvider).syncProfile(
              accessToken: accessToken ?? session.accessToken,
              profile: profile,
            );
        ref.invalidate(socialMeProvider);
        ref.invalidate(friendsHubProvider);
      }

      if (newPassword.isNotEmpty) {
        await authController.setOrChangePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isEditing = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _draftFingerprint = null;
        _draftPhotoUrl = photoUrl;
      });
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            newPassword.isEmpty ? 'Profile saved' : 'Profile and password saved',
          ),
        ),
      );
    } on AuthException catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text(error.message)));
    } on SocialApiException catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path?.trim();
    if (path == null || path.isEmpty) {
      return;
    }

    setState(() {
      _draftPhotoUrl = path;
    });
  }
}

class _ProfileAtmosphere extends StatelessWidget {
  const _ProfileAtmosphere();

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

class _ProfileScrollView extends StatelessWidget {
  const _ProfileScrollView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, _profileBottomPadding),
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

class _ProfileHorizontalPadding extends StatelessWidget {
  const _ProfileHorizontalPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({
    required this.isEditing,
    required this.isSaving,
    required this.canSave,
    required this.onBack,
    required this.onEditOrSave,
  });

  final bool isEditing;
  final bool isSaving;
  final bool canSave;
  final VoidCallback onBack;
  final VoidCallback onEditOrSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 16,
      color: scheme.surface.withValues(alpha: 0.58),
      borderColor: scheme.primaryContainer.withValues(alpha: 0.14),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 42,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: !isEditing || canSave ? onEditOrSave : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
                  icon: isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onSurface,
                          ),
                        )
                      : Icon(
                          isEditing ? Icons.check_rounded : Icons.edit_outlined,
                          size: 20,
                          color: !isEditing || canSave
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.34),
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

class _PasswordCard extends StatelessWidget {
  const _PasswordCard({
    required this.hasPasswordProvider,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.onChanged,
  });

  final bool hasPasswordProvider;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
        radius: 32,
        blurSigma: 18,
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderColor: colorScheme.primaryContainer.withValues(alpha: 0.14),
        shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Change password',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 14),
          if (hasPasswordProvider) ...<Widget>[
            ProfileTextField(
              controller: currentPasswordController,
              label: 'Current password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
          ],
          ProfileTextField(
            controller: newPasswordController,
            label: hasPasswordProvider ? 'New password' : 'Set password',
            icon: Icons.password_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          ProfileTextField(
            controller: confirmPasswordController,
            label: 'Confirm password',
            icon: Icons.verified_user_outlined,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
