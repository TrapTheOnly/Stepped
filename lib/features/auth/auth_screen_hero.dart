part of 'auth_screen.dart';

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.mode,
  });

  final _AuthPanelMode mode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSignIn = mode == _AuthPanelMode.signIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FrostedSquircle(
          radius: 30,
          blurSigma: 20,
          color: colorScheme.surface.withValues(alpha: 0.42),
          borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
          shadowColor: colorScheme.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: squircleShape(38),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      colorScheme.primaryContainer.withValues(alpha: 0.94),
                      colorScheme.secondaryContainer.withValues(alpha: 0.84),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/branding/stepped_monochrome_logo.png',
                    width: 108,
                    height: 108,
                    fit: BoxFit.cover,
                    color: colorScheme.onPrimaryContainer,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'STEPPED',
                      style: textTheme.titleLarge?.copyWith(
                        letterSpacing: 2.8,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSignIn
                          ? 'Your world, reopened'
                          : 'World begins here...',
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
        const SizedBox(height: 16),
        Text(
          isSignIn ? 'Welcome back to your world.' : 'Start discovering the world!',
          style: textTheme.displayMedium?.copyWith(
            fontSize: 34,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _ModeSegmentControl extends StatelessWidget {
  const _ModeSegmentControl({
    required this.mode,
    required this.onChanged,
  });

  final _AuthPanelMode mode;
  final ValueChanged<_AuthPanelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.34),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        height: 56,
        child: Stack(
          children: <Widget>[
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: mode == _AuthPanelMode.signIn
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: squircleShape(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          colorScheme.primary,
                          colorScheme.primaryContainer,
                        ],
                      ),
                      shadows: <BoxShadow>[
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ModeSegmentButton(
                    label: 'Sign in',
                    selected: mode == _AuthPanelMode.signIn,
                    onTap: () => onChanged(_AuthPanelMode.signIn),
                  ),
                ),
                Expanded(
                  child: _ModeSegmentButton(
                    label: 'Register',
                    selected: mode == _AuthPanelMode.register,
                    onTap: () => onChanged(_AuthPanelMode.register),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegmentButton extends StatelessWidget {
  const _ModeSegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor:
            selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        shape: squircleShape(24),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
