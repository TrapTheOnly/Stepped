import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/frosted_squircle.dart';
import '../../widgets/person_avatar.dart';
import '../../widgets/shell_scaffold_inset.dart';
import '../../widgets/stepped_top_bar.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with WidgetsBindingObserver {
  SocialInviteLink? _latestInvite;
  bool _isGeneratingInvite = false;
  String? _deletingInviteToken;
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSocialState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubAsync = ref.watch(friendsHubProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final bottomBarHeight = ShellScaffoldInset.bottomBarHeightOf(context);
    final scrollBottomPadding = bottomBarHeight + 36;

    return ColoredBox(
      color: colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(
              child: _FriendsAtmosphere(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SteppedTopBar(
                    onOpenSettings: () => context.push('/profile/settings'),
                    onOpenProfile: () => context.push('/profile'),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: hubAsync.when(
                    skipLoadingOnRefresh: true,
                    skipLoadingOnReload: true,
                    loading: () => _FriendsScrollView(
                      bottomPadding: scrollBottomPadding,
                      children: const <Widget>[
                        _FriendsHorizontalPadding(child: _FriendsHeader()),
                        SizedBox(height: 28),
                        _FriendsHorizontalPadding(
                          child: _FriendsStatusCard(
                            title: 'Loading your circle',
                            message:
                                'Checking your invite link and loading confirmed friends.',
                            showProgress: true,
                          ),
                        ),
                      ],
                    ),
                    error: (error, _) => _FriendsScrollView(
                      bottomPadding: scrollBottomPadding,
                      children: <Widget>[
                        const _FriendsHorizontalPadding(
                            child: _FriendsHeader()),
                        const SizedBox(height: 28),
                        _FriendsHorizontalPadding(
                          child: _FriendsStatusCard(
                            title: 'Friends unavailable',
                            message: _messageForError(error),
                          ),
                        ),
                      ],
                    ),
                    data: (hub) {
                      final invites = _mergedInvites(hub.me.invites);
                      SocialInviteLink? activeInvite;
                      for (final invite in invites) {
                        if (invite.isActive) {
                          activeInvite = invite;
                          break;
                        }
                      }
                      final archivedInvites = invites
                          .where(
                              (invite) => invite.token != activeInvite?.token)
                          .toList();
                      final activeInviteForActions = activeInvite;

                      return _FriendsScrollView(
                        bottomPadding: scrollBottomPadding,
                        children: <Widget>[
                          const _FriendsHorizontalPadding(
                              child: _FriendsHeader()),
                          const SizedBox(height: 32),
                          const _FriendsHorizontalPadding(
                            child: _SectionHeading(
                              eyebrow: 'Your circle',
                              title: 'Friends',
                              subtitle: '',
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (hub.friends.isEmpty)
                            const _FriendsHorizontalPadding(
                              child: _FriendsStatusCard(
                                title: 'No friends yet',
                                message:
                                    'Generate a link and share it to start building your travel circle.',
                              ),
                            )
                          else
                            for (final friend in hub.friends) ...<Widget>[
                              _FriendsHorizontalPadding(
                                child: _FriendListCard(
                                  friend: friend,
                                  onTap: () => context.push(
                                    '/friends/profile/${friend.id}',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          const SizedBox(height: 28),
                          const _FriendsHorizontalPadding(
                            child: _SectionHeading(
                              eyebrow: 'Invite',
                              title: 'Share your path',
                              subtitle:
                                  'Generate a fresh link when you want someone new to join your circle.',
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FriendsHorizontalPadding(
                            child: _InviteCard(
                              invite: activeInvite,
                              isGenerating: _isGeneratingInvite,
                              onCopy: activeInviteForActions == null
                                  ? null
                                  : () => _copyInvite(
                                        activeInviteForActions.shareUrl,
                                      ),
                              onDelete: activeInviteForActions == null
                                  ? null
                                  : () => _deleteInvite(activeInviteForActions),
                              onGenerate: _generateInvite,
                            ),
                          ),
                          if (archivedInvites.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 18),
                            const _FriendsHorizontalPadding(
                              child: Text(
                                'Saved links',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final invite in archivedInvites) ...<Widget>[
                              _FriendsHorizontalPadding(
                                child: _InviteHistoryCard(
                                  invite: invite,
                                  isDeleting:
                                      _deletingInviteToken == invite.token,
                                  onCopy: () => _copyInvite(invite.shareUrl),
                                  onDelete: () => _deleteInvite(invite),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyInvite(String inviteUrl) async {
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Friend link copied')),
    );
  }

  Future<void> _generateInvite() async {
    final session = ref.read(socialSessionProvider);
    if (session == null || _isGeneratingInvite) {
      return;
    }

    setState(() {
      _isGeneratingInvite = true;
    });

    try {
      final invite = await ref.read(socialApiClientProvider).createFriendLink(
            accessToken: session.accessToken,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestInvite = invite;
      });
      _refreshSocialState(force: true);
      await _copyInvite(invite.shareUrl);
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
          _isGeneratingInvite = false;
        });
      }
    }
  }

  Future<void> _deleteInvite(SocialInviteLink invite) async {
    final session = ref.read(socialSessionProvider);
    if (session == null || _deletingInviteToken != null) {
      return;
    }

    setState(() {
      _deletingInviteToken = invite.token;
    });

    try {
      await ref.read(socialApiClientProvider).deleteFriendLink(
            accessToken: session.accessToken,
            token: invite.token,
          );
      if (!mounted) {
        return;
      }
      if (_latestInvite?.token == invite.token) {
        _latestInvite = null;
      }
      _refreshSocialState(force: true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Friend link deleted')),
      );
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
          _deletingInviteToken = null;
        });
      }
    }
  }

  String _messageForError(Object error) {
    if (error is SocialApiException) {
      return error.message;
    }
    return 'We could not load your social state right now.';
  }

  void _refreshSocialState({bool force = false}) {
    final now = DateTime.now();
    if (!force && _lastRefreshAt != null) {
      final elapsed = now.difference(_lastRefreshAt!);
      if (elapsed < const Duration(seconds: 20)) {
        return;
      }
    }
    _lastRefreshAt = now;
    ref.invalidate(socialMeProvider);
    unawaited(ref.read(friendsHubProvider.notifier).refresh());
  }

  List<SocialInviteLink> _mergedInvites(List<SocialInviteLink> invites) {
    final merged = <SocialInviteLink>[
      ...invites,
      if (_latestInvite != null &&
          invites.every((invite) => invite.token != _latestInvite!.token))
        _latestInvite!,
    ];
    final deduped = <SocialInviteLink>[];
    final seenTokens = <String>{};
    for (final invite in merged) {
      final normalizedToken = invite.token.trim();
      if (normalizedToken.isEmpty || seenTokens.contains(normalizedToken)) {
        continue;
      }
      seenTokens.add(normalizedToken);
      deduped.add(invite);
    }
    deduped.sort((a, b) {
      final activeComparison =
          (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
      if (activeComparison != 0) {
        return activeComparison;
      }
      final aCreatedAt = a.createdAt;
      final bCreatedAt = b.createdAt;
      if (aCreatedAt == null && bCreatedAt == null) {
        return 0;
      }
      if (aCreatedAt == null) {
        return 1;
      }
      if (bCreatedAt == null) {
        return -1;
      }
      return bCreatedAt.compareTo(aCreatedAt);
    });
    return deduped;
  }
}

class _FriendsAtmosphere extends StatelessWidget {
  const _FriendsAtmosphere();

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
            center: const Alignment(0.9, -0.8),
            radius: 1.0,
            colors: <Color>[
              colorScheme.secondary.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsScrollView extends StatelessWidget {
  const _FriendsScrollView({
    required this.children,
    required this.bottomPadding,
  });

  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
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

class _FriendsHorizontalPadding extends StatelessWidget {
  const _FriendsHorizontalPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class _FriendsHeader extends StatelessWidget {
  const _FriendsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Friends',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 42,
                  height: 1.04,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share your public travel journal and follow the people you travel with.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedSubtitle = subtitle.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.6,
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (normalizedSubtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            normalizedSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ],
    );
  }
}

class _FriendsStatusCard extends StatelessWidget {
  const _FriendsStatusCard({
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
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.isGenerating,
    required this.onCopy,
    required this.onDelete,
    required this.onGenerate,
  });

  final SocialInviteLink? invite;
  final bool isGenerating;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shareUrl = invite?.shareUrl;
    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Friend link',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            shareUrl ??
                'Generate a fresh invite URL that people can use to add you.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: invite == null
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 16),
          if (invite == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isGenerating ? null : onGenerate,
                icon: isGenerating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link_rounded),
                label: const Text('Generate link'),
              ),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isGenerating ? null : onGenerate,
                    icon: isGenerating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('New link'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.content_copy_rounded),
                    label: const Text('Copy link'),
                  ),
                ),
              ],
            ),
          if (invite != null) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Text(
                  invite!.shortStatusLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        letterSpacing: 0.6,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete active link'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteHistoryCard extends StatelessWidget {
  const _InviteHistoryCard({
    required this.invite,
    required this.isDeleting,
    required this.onCopy,
    required this.onDelete,
  });

  final SocialInviteLink invite;
  final bool isDeleting;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.68),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Link',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 10),
              Text(
                invite.shortStatusLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: invite.isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            invite.shareUrl,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('Copy link'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: isDeleting ? null : onDelete,
                icon: isDeleting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendListCard extends StatelessWidget {
  const _FriendListCard({
    required this.friend,
    required this.onTap,
  });

  final FriendSummary friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final addedLabel = friend.addedAt == null
        ? null
        : DateFormat.yMMMd().format(friend.addedAt!.toLocal());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.pressed)
              ? colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: FrostedSquircle(
          radius: 28,
          blurSigma: 18,
          color: colorScheme.surface.withValues(alpha: 0.70),
          borderColor: colorScheme.primaryContainer.withValues(alpha: 0.12),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: <Widget>[
              PersonAvatar(
                displayName: friend.displayName,
                photoUrl: friend.photoUrl,
                radius: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      friend.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend.homeBase.isEmpty
                          ? 'Home base not set'
                          : friend.homeBase,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (addedLabel != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Added $addedLabel',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
