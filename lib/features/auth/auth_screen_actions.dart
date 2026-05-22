part of 'auth_screen.dart';

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;
    final isDark = colorScheme.brightness == Brightness.dark;

    return IgnorePointer(
      ignoring: !isEnabled,
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: ShapeDecoration(
              shape: squircleShape(22),
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              shadows: isEnabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.24 : 0.28,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 9),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              onTap: onPressed,
              customBorder: squircleShape(22),
              overlayColor: WidgetStatePropertyAll<Color>(
                colorScheme.onPrimary.withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isEnabled
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 20,
                    color: isEnabled
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
