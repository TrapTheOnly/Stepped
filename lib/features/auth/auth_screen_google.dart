part of 'auth_screen.dart';

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return const _GoogleMark(size: 20);
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.58 : 1,
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            child: Ink(
              decoration: ShapeDecoration(
                shape: squircleShape(
                  26,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.20),
                  ),
                ),
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
                shadows: <BoxShadow>[
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: InkWell(
                onTap: onPressed,
                customBorder: squircleShape(26),
                overlayColor: WidgetStatePropertyAll<Color>(
                  colorScheme.primary.withValues(alpha: 0.05),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const _GoogleBadge(),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: 17,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GoogleMarkPainter(),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.24;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bluePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth
      ..color = _blue;
    final redPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth
      ..color = _red;
    final yellowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth
      ..color = _yellow;
    final greenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth
      ..color = _green;

    canvas.drawArc(rect, _deg(-40), _deg(90), false, bluePaint);
    canvas.drawArc(rect, _deg(50), _deg(80), false, greenPaint);
    canvas.drawArc(rect, _deg(130), _deg(70), false, yellowPaint);
    canvas.drawArc(rect, _deg(200), _deg(115), false, redPaint);

    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth
      ..color = _blue;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - strokeWidth * 0.15, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;

  double _deg(double value) => value * math.pi / 180.0;
}
