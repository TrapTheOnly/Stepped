import 'dart:ui';

import 'package:flutter/material.dart';

ContinuousRectangleBorder squircleShape(
  double radius, {
  BorderSide side = BorderSide.none,
}) {
  return ContinuousRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: side,
  );
}

class FrostedSquircle extends StatelessWidget {
  const FrostedSquircle({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 32,
    this.color,
    this.borderColor,
    this.blurSigma = 18,
    this.shadowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final double blurSigma;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor = color ?? colorScheme.surface.withValues(alpha: 0.76);
    final outlineColor =
        borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.22);
    final ambientShadow =
        shadowColor ?? colorScheme.primary.withValues(alpha: 0.10);
    final shape = squircleShape(
      radius,
      side: BorderSide(color: outlineColor, width: 1),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: squircleShape(radius),
        shadows: <BoxShadow>[
          BoxShadow(
            color: ambientShadow,
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: squircleShape(radius)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: fillColor,
              shape: shape,
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
