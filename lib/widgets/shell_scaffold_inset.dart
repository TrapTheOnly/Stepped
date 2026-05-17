import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ShellScaffoldInset extends InheritedNotifier<ValueNotifier<double>> {
  const ShellScaffoldInset({
    super.key,
    required ValueNotifier<double> bottomBarHeight,
    required super.child,
  }) : super(notifier: bottomBarHeight);

  static double bottomBarHeightOf(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<ShellScaffoldInset>();
    return inherited?.notifier?.value ?? 0;
  }
}

class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderMeasureSize(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class RenderMeasureSize extends RenderProxyBox {
  RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _lastReportedSize;

  @override
  void performLayout() {
    super.performLayout();
    final nextSize = child?.size ?? size;
    if (_lastReportedSize == nextSize) {
      return;
    }
    _lastReportedSize = nextSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(nextSize);
    });
  }
}
