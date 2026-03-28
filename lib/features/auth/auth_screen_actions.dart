part of 'auth_screen.dart';

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.55,
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
                shape: squircleShape(26),
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
                    color: colorScheme.primary.withValues(alpha: 0.20),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: InkWell(
                onTap: onPressed,
                customBorder: squircleShape(26),
                overlayColor: WidgetStatePropertyAll<Color>(
                  colorScheme.onPrimary.withValues(alpha: 0.06),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontSize: 17,
                        ),
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
