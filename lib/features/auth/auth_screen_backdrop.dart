part of 'auth_screen.dart';

class _AnimatedBackdrop extends StatelessWidget {
  const _AnimatedBackdrop({
    required this.controller,
    required this.colorScheme,
  });

  final AnimationController controller;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    return AnimatedBuilder(
      animation: t,
      builder: (context, child) {
        final value = t.value;
        final wobble = math.sin(value * math.pi * 2);

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                colorScheme.surface,
                colorScheme.surfaceContainerLow.withValues(alpha: 0.98),
                colorScheme.surfaceContainer.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -140 + (wobble * 30),
                left: -80 + (wobble * 22),
                child: _Orb(
                  diameter: 260,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.42),
                ),
              ),
              Positioned(
                top: 110 - (wobble * 14),
                right: -120 + (wobble * 28),
                child: _Orb(
                  diameter: 250,
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.24),
                ),
              ),
              Positioned(
                bottom: -150 + (wobble * 18),
                left: 18 - (wobble * 14),
                child: _Orb(
                  diameter: 280,
                  color: colorScheme.secondary.withValues(alpha: 0.14),
                ),
              ),
              Positioned(
                bottom: 180 - (wobble * 16),
                left: 120 + (wobble * 12),
                child: _Orb(
                  diameter: 170,
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.26),
              blurRadius: 80,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}
