import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../../widgets/frosted_squircle.dart';
import '../../widgets/person_avatar.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';

const _inviteBottomContentPadding = 24.0;

class FriendLinkAcceptScreen extends ConsumerStatefulWidget {
  const FriendLinkAcceptScreen({
    super.key,
    required this.token,
  });

  final String token;

  @override
  ConsumerState<FriendLinkAcceptScreen> createState() =>
      _FriendLinkAcceptScreenState();
}

class _FriendLinkAcceptScreenState
    extends ConsumerState<FriendLinkAcceptScreen> {
  bool _isAccepting = false;
  FriendAcceptResult? _acceptedResult;

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(friendInvitePreviewProvider(widget.token));
    final meAsync = ref.watch(socialMeProvider);
    final authController = ref.watch(authControllerProvider);
    final localProfile = ref.watch(socialProfileSnapshotProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final ownInvite = _ownInviteFor(meAsync.valueOrNull, widget.token);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: ColoredBox(
        color: colorScheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(child: _InviteAtmosphere()),
            ),
            Column(
              children: <Widget>[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _InviteTopBar(onBack: _goBack),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildScrollLayer(
                    previewAsync,
                    ownInvite: ownInvite,
                    localProfile: localProfile,
                    currentEmail: authController.currentUser?.email ?? '',
                    currentPhotoUrl: authController.currentUser?.photoUrl,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: _buildActionArea(
                          previewAsync,
                          ownInvite: ownInvite,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollLayer(
    AsyncValue<FriendInvitePreview> previewAsync, {
    required SocialInviteLink? ownInvite,
    required SocialProfileSnapshot localProfile,
    required String currentEmail,
    required String? currentPhotoUrl,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        _inviteBottomContentPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (ownInvite != null)
                _OwnInviteCard(
                  invite: ownInvite,
                  displayName: localProfile.displayName,
                  email: currentEmail,
                  photoUrl: currentPhotoUrl ?? localProfile.photoUrl,
                  homeBase: localProfile.homeBase,
                )
              else
                previewAsync.when(
                  loading: () => const _InviteStatusCard(
                    title: 'Opening invite',
                    message:
                        'Looking up this friend link and preparing the traveler profile.',
                    showProgress: true,
                  ),
                  error: (error, _) => _InviteStatusCard(
                    title: 'Invite unavailable',
                    message: _messageForError(error),
                  ),
                  data: (preview) => _InviteProfileCard(
                    preview: preview,
                    acceptedResult: _acceptedResult,
                    isAccepting: _isAccepting,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionArea(
    AsyncValue<FriendInvitePreview> previewAsync, {
    required SocialInviteLink? ownInvite,
  }) {
    if (ownInvite != null) {
      return _InviteActionStack(
        primaryLabel: 'Copy invite link',
        primaryTone: _InviteActionTone.primary,
        primaryStatic: false,
        onPrimary: () => _copyOwnInvite(ownInvite.shareUrl),
        onSecondary: _goBack,
      );
    }

    return previewAsync.when(
      loading: () => _InviteActionStack(
        primaryLabel: 'Opening invite',
        primaryTone: _InviteActionTone.primary,
        primaryStatic: true,
        showPrimaryProgress: true,
        onSecondary: _goBack,
      ),
      error: (error, _) => _InviteActionStack(
        primaryLabel: 'Invite unavailable',
        primaryTone: _InviteActionTone.neutral,
        primaryStatic: true,
        onSecondary: _goBack,
      ),
      data: (preview) {
        final state = _inviteStateFor(preview);
        return _InviteActionStack(
          primaryLabel: state.primaryLabel,
          primaryTone: state.primaryTone,
          primaryStatic: state.primaryStatic,
          showPrimaryProgress: _isAccepting,
          onPrimary: state.onPrimary,
          onSecondary: _goBack,
        );
      },
    );
  }

  _InviteState _inviteStateFor(FriendInvitePreview preview) {
    if (_acceptedResult != null) {
      return const _InviteState(
        primaryLabel: 'Now friends',
        primaryTone: _InviteActionTone.success,
        primaryStatic: true,
      );
    }

    final normalizedStatus = preview.status.toLowerCase();
    if (normalizedStatus == 'already_friends' ||
        normalizedStatus == 'accepted') {
      return const _InviteState(
        primaryLabel: 'Already friends',
        primaryTone: _InviteActionTone.success,
        primaryStatic: true,
      );
    }

    if (preview.canAccept) {
      return _InviteState(
        primaryLabel: _isAccepting ? 'Adding friend...' : 'Add as friend',
        primaryTone: _InviteActionTone.primary,
        primaryStatic: false,
        onPrimary: _isAccepting ? null : _acceptInvite,
      );
    }

    return _InviteState(
      primaryLabel: _primaryLabelForUnavailableStatus(normalizedStatus),
      primaryTone: _InviteActionTone.neutral,
      primaryStatic: true,
    );
  }

  Future<void> _acceptInvite() async {
    final session = ref.read(socialSessionProvider);
    if (session == null || _isAccepting) {
      return;
    }

    setState(() {
      _isAccepting = true;
    });

    try {
      final result = await ref.read(socialApiClientProvider).acceptFriendLink(
            accessToken: session.accessToken,
            token: widget.token,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _acceptedResult = result;
      });
      ref.invalidate(socialFriendsProvider);
      ref.invalidate(friendsHubProvider);
      ref.invalidate(socialMeProvider);
    } on SocialApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/');
  }

  Future<void> _copyOwnInvite(String inviteUrl) async {
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Friend link copied')),
    );
  }

  String _primaryLabelForUnavailableStatus(String status) {
    switch (status) {
      case 'expired':
        return 'Invite expired';
      case 'self':
        return 'This is your link';
      case 'used':
        return 'Invite already used';
      default:
        return 'Invite unavailable';
    }
  }

  String _messageForError(Object error) {
    if (error is SocialApiException) {
      return error.message;
    }
    return 'We could not open this invite right now.';
  }

  SocialInviteLink? _ownInviteFor(SocialMeData? me, String token) {
    if (me == null) {
      return null;
    }
    final normalizedToken = token.trim();
    for (final invite in me.invites) {
      if (invite.token.trim() == normalizedToken) {
        return invite;
      }
    }
    return null;
  }
}

class _InviteState {
  const _InviteState({
    required this.primaryLabel,
    required this.primaryTone,
    required this.primaryStatic,
    this.onPrimary,
  });

  final String primaryLabel;
  final _InviteActionTone primaryTone;
  final bool primaryStatic;
  final VoidCallback? onPrimary;
}

enum _InviteActionTone {
  primary,
  success,
  neutral,
}

class _InviteAtmosphere extends StatelessWidget {
  const _InviteAtmosphere();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colorScheme.surface.withValues(alpha: 0.06),
            colorScheme.surface,
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.15, -0.92),
            radius: 1.08,
            colors: <Color>[
              colorScheme.secondary.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteTopBar extends StatelessWidget {
  const _InviteTopBar({required this.onBack});

  final VoidCallback onBack;

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
              'STEPPED',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    letterSpacing: 2.8,
                    fontSize: 25,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteStatusCard extends StatelessWidget {
  const _InviteStatusCard({
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.74),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
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

class _OwnInviteCard extends StatelessWidget {
  const _OwnInviteCard({
    required this.invite,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.homeBase,
  });

  final SocialInviteLink invite;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String homeBase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 34,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.74),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _InviteBadge(
            label: 'Your invite',
            tone: _InviteActionTone.primary,
          ),
          const SizedBox(height: 20),
          PersonAvatar(
            displayName: displayName,
            photoUrl: photoUrl,
            radius: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'YOUR ACTIVE LINK',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            email.trim().isEmpty ? 'Signed-in traveler' : email.trim(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          if (homeBase.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text(
                  homeBase,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        letterSpacing: 0.4,
                      ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'You opened your own invite link. Share it with a different traveler account or another device to add someone to your circle.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.84),
                  height: 1.42,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            invite.shareUrl,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _InviteProfileCard extends StatelessWidget {
  const _InviteProfileCard({
    required this.preview,
    required this.acceptedResult,
    required this.isAccepting,
  });

  final FriendInvitePreview preview;
  final FriendAcceptResult? acceptedResult;
  final bool isAccepting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName =
        acceptedResult?.friend.displayName ?? preview.inviterName;
    final photoUrl = acceptedResult?.friend.photoUrl ?? preview.inviterPhotoUrl;
    final homeBase = acceptedResult?.friend.homeBase ?? preview.inviterHomeBase;
    final email = preview.inviterEmail.trim().isEmpty
        ? 'Invite email not shared'
        : preview.inviterEmail.trim();
    final normalizedStatus = preview.status.toLowerCase();
    final isAccepted = acceptedResult != null;
    final isAlreadyFriends =
        normalizedStatus == 'already_friends' || normalizedStatus == 'accepted';

    final eyebrow = isAccepted
        ? 'Travel circle updated'
        : isAlreadyFriends
            ? 'Already connected'
            : preview.canAccept
                ? 'Travel circle invite'
                : 'Invite status';
    final supportingText = _supportingText(
      preview: preview,
      isAccepted: isAccepted,
      isAlreadyFriends: isAlreadyFriends,
      isAccepting: isAccepting,
    );

    return FrostedSquircle(
      radius: 34,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.74),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _InviteBadge(
            label: _badgeLabelFor(
              preview: preview,
              isAccepted: isAccepted,
              isAlreadyFriends: isAlreadyFriends,
            ),
            tone: isAccepted || isAlreadyFriends
                ? _InviteActionTone.success
                : preview.canAccept
                    ? _InviteActionTone.primary
                    : _InviteActionTone.neutral,
          ),
          const SizedBox(height: 20),
          PersonAvatar(
            displayName: displayName,
            photoUrl: photoUrl,
            radius: 40,
          ),
          const SizedBox(height: 16),
          Text(
            eyebrow.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          if (homeBase.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text(
                  homeBase,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        letterSpacing: 0.4,
                      ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            supportingText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.84),
                  height: 1.42,
                ),
          ),
        ],
      ),
    );
  }

  String _badgeLabelFor({
    required FriendInvitePreview preview,
    required bool isAccepted,
    required bool isAlreadyFriends,
  }) {
    if (isAccepted) {
      return 'Now friends';
    }
    if (isAlreadyFriends) {
      return 'Already friends';
    }
    if (preview.canAccept) {
      return 'Ready to add';
    }

    switch (preview.status.toLowerCase()) {
      case 'expired':
        return 'Expired';
      case 'self':
        return 'Your invite';
      case 'used':
        return 'Used';
      default:
        return 'Unavailable';
    }
  }

  String _supportingText({
    required FriendInvitePreview preview,
    required bool isAccepted,
    required bool isAlreadyFriends,
    required bool isAccepting,
  }) {
    if (isAccepting) {
      return 'Adding this traveler to your circle and refreshing the shared profile state.';
    }
    if (isAccepted) {
      return 'You are connected now. Use the button below to head back into the app and continue from where you left off.';
    }
    if (isAlreadyFriends) {
      return 'You already have access to this traveler in your circle, so there is nothing else you need to do here.';
    }
    if (preview.canAccept) {
      return 'Accept this invitation to follow their public travel profile inside Stepped and keep your circle in sync.';
    }

    switch (preview.status.toLowerCase()) {
      case 'expired':
        return 'This invitation has expired. Ask your friend to generate a fresh link and send it again.';
      case 'self':
        return 'This link belongs to your own account, so it cannot be accepted as a friend invite.';
      case 'used':
        return 'This invitation was already used. A new link is needed before you can join this circle.';
      default:
        return 'This invitation cannot be accepted right now. Try again later or ask for a fresh link.';
    }
  }
}

class _InviteBadge extends StatelessWidget {
  const _InviteBadge({
    required this.label,
    required this.tone,
  });

  final String label;
  final _InviteActionTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = switch (tone) {
      _InviteActionTone.primary => colorScheme.primaryContainer,
      _InviteActionTone.success => Colors.green.shade600,
      _InviteActionTone.neutral => colorScheme.surface.withValues(alpha: 0.82),
    };
    final foregroundColor = switch (tone) {
      _InviteActionTone.primary => colorScheme.onPrimaryContainer,
      _InviteActionTone.success => Colors.white,
      _InviteActionTone.neutral => colorScheme.onSurface,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _InviteActionStack extends StatelessWidget {
  const _InviteActionStack({
    required this.primaryLabel,
    required this.primaryTone,
    required this.primaryStatic,
    required this.onSecondary,
    this.onPrimary,
    this.showPrimaryProgress = false,
  });

  final String primaryLabel;
  final _InviteActionTone primaryTone;
  final bool primaryStatic;
  final VoidCallback? onPrimary;
  final VoidCallback onSecondary;
  final bool showPrimaryProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryFillColor = switch (primaryTone) {
      _InviteActionTone.primary => colorScheme.primaryContainer.withValues(
          alpha: 0.78,
        ),
      _InviteActionTone.success => Colors.green.shade600,
      _InviteActionTone.neutral => colorScheme.surface.withValues(alpha: 0.72),
    };
    final primaryForegroundColor = switch (primaryTone) {
      _InviteActionTone.primary => colorScheme.onPrimaryContainer,
      _InviteActionTone.success => Colors.white,
      _InviteActionTone.neutral => colorScheme.onSurface,
    };

    Widget primaryButton = _InviteDockButton(
      label: primaryLabel,
      icon: switch (primaryTone) {
        _InviteActionTone.primary => Icons.person_add_alt_rounded,
        _InviteActionTone.success => Icons.check_rounded,
        _InviteActionTone.neutral => Icons.link_off_rounded,
      },
      onTap: primaryStatic ? () {} : onPrimary,
      fillColor: primaryFillColor,
      foregroundColor: primaryForegroundColor,
      loading: showPrimaryProgress,
    );

    if (primaryStatic) {
      primaryButton = AbsorbPointer(child: primaryButton);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        primaryButton,
        const SizedBox(height: 12),
        _InviteDockButton(
          label: 'Go back',
          icon: Icons.arrow_back_rounded,
          onTap: onSecondary,
        ),
      ],
    );
  }
}

class _InviteDockButton extends StatelessWidget {
  const _InviteDockButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.fillColor,
    this.foregroundColor,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? fillColor;
  final Color? foregroundColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedFillColor =
        fillColor ?? scheme.surface.withValues(alpha: 0.72);
    final resolvedForegroundColor = foregroundColor ?? scheme.onSurface;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: resolvedFillColor,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.14),
      shadowColor: scheme.primary.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (loading)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.1,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        resolvedForegroundColor,
                      ),
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 22,
                    color: resolvedForegroundColor,
                  ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: resolvedForegroundColor,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
