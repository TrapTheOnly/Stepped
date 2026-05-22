part of 'auth_screen.dart';

const _brandLogoAsset = 'assets/branding/stepped_logo.png';
const _authCanopyAsset = 'assets/branding/auth_canopy.png';

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final heroHeight = 265 - (39 * progress);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: heroHeight,
      decoration: ShapeDecoration(
        shape: squircleShape(46),
        shadows: <BoxShadow>[
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: squircleShape(46)),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              _authCanopyAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    colorScheme.surface.withValues(alpha: isDark ? 0.38 : 0.22),
                    colorScheme.surface.withValues(alpha: isDark ? 0.96 : 0.92),
                  ],
                  stops: const <double>[0.12, 0.54, 1],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surface.withValues(alpha: 0.28)
                    : Colors.transparent,
              ),
            ),
            Align(
              alignment: Alignment(0, -0.10 + (0.06 * progress)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.surface,
                        width: 4,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colorScheme.shadow.withValues(
                            alpha: isDark ? 0.34 : 0.22,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _brandLogoAsset,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Stepped',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 29,
                      color:
                          isDark ? colorScheme.onSurface : colorScheme.primary,
                      shadows: <Shadow>[
                        Shadow(
                          color: colorScheme.surface.withValues(alpha: 0.52),
                          blurRadius: 8,
                        ),
                      ],
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
