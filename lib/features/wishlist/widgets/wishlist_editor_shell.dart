import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';
import 'wishlist_editorial_widgets.dart';

const wishlistEditorTopOverlayClearance = 118.0;
const wishlistEditorBottomDockClearance = 148.0;

InputDecorationTheme wishlistEditorInputDecorationTheme(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide(
      color: scheme.outlineVariant.withValues(alpha: 0.18),
    ),
  );
  return InputDecorationTheme(
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: scheme.primary.withValues(alpha: 0.34),
        width: 1.1,
      ),
    ),
    errorBorder: border.copyWith(
      borderSide: BorderSide(
        color: scheme.error.withValues(alpha: 0.54),
      ),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: BorderSide(
        color: scheme.error,
        width: 1.1,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  );
}

class WishlistEditorShell extends StatelessWidget {
  const WishlistEditorShell({
    super.key,
    required this.title,
    required this.body,
    required this.onBack,
    this.topActions = const <Widget>[],
    this.bottomDock,
  });

  final String title;
  final Widget body;
  final VoidCallback onBack;
  final List<Widget> topActions;
  final Widget? bottomDock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
        color: scheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(
                child: WishlistAtmosphere(),
              ),
            ),
            Positioned.fill(child: body),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _WishlistEditorTopBar(
                    title: title,
                    onBack: onBack,
                    actions: topActions,
                  ),
                ),
              ),
            ),
            if (bottomDock != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SafeArea(
                  top: false,
                  child: bottomDock!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WishlistEditorSectionCard extends StatelessWidget {
  const WishlistEditorSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: scheme.surface.withValues(alpha: 0.74),
      borderColor: scheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: scheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class WishlistEditorDockButton extends StatelessWidget {
  const WishlistEditorDockButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.highlighted = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fillColor = highlighted
        ? scheme.primaryContainer.withValues(alpha: 0.76)
        : scheme.surface.withValues(alpha: 0.72);

    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: fillColor,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.14),
      shadowColor: scheme.primary.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (isLoading)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: highlighted
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 22,
                    color: highlighted
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                  ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: highlighted
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
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

class WishlistEditorStatusView extends StatelessWidget {
  const WishlistEditorStatusView({
    super.key,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: WishlistEditorSectionCard(
            title: title,
            subtitle: message,
            child: showProgress
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(minHeight: 6),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class WishlistEditorHeroCard extends StatelessWidget {
  const WishlistEditorHeroCard({
    super.key,
    required this.title,
    required this.badge,
    this.subtitle,
    this.imageUrl,
    this.chips = const <String>[],
  });

  final String title;
  final String badge;
  final String? subtitle;
  final String? imageUrl;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _WishlistHeroArtworkLayer(imageUrl: imageUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const <double>[0, 0.38, 1],
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: _HeroGlassPill(label: badge),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title.trim().isEmpty ? 'Untitled idea' : title.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                            height: 0.98,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null &&
                        subtitle!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    if (chips.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: chips
                            .map((chip) => _HeroGlassPill(label: chip))
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WishlistEditorTopBar extends StatelessWidget {
  const _WishlistEditorTopBar({
    required this.title,
    required this.onBack,
    required this.actions,
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget> actions;

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
        height: 34,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 82,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _WishlistEditorTopBarButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      height: 1,
                    ),
              ),
            ),
            SizedBox(
              width: 82,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistEditorTopBarButton extends StatelessWidget {
  const _WishlistEditorTopBarButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 20,
        color: onTap == null
            ? scheme.onSurface.withValues(alpha: 0.34)
            : scheme.onSurface,
      ),
    );
  }
}

class _WishlistHeroArtworkLayer extends StatelessWidget {
  const _WishlistHeroArtworkLayer({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return const _WishlistHeroPlaceholderLayer();
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _WishlistHeroPlaceholderLayer(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return const _WishlistHeroPlaceholderLayer();
      },
    );
  }
}

class _WishlistHeroPlaceholderLayer extends StatelessWidget {
  const _WishlistHeroPlaceholderLayer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surfaceContainerHigh.withValues(alpha: 0.92),
            scheme.surfaceContainer.withValues(alpha: 0.86),
            scheme.surfaceContainerLow.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.6, -0.2),
            radius: 1.25,
            colors: <Color>[
              scheme.primary.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroGlassPill extends StatelessWidget {
  const _HeroGlassPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: squircleShape(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
