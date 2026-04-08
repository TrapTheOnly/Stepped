import 'package:flutter/material.dart';

import 'shell_scaffold_inset.dart';

typedef EditorialOverlayBodyBuilder = Widget Function(
  BuildContext context,
  double topContentInset,
  double bottomBarHeight,
);

typedef EditorialOverlayFloatingBuilder = Widget Function(
  BuildContext context,
  double bottomBarHeight,
);

class EditorialOverlayPageScope extends InheritedWidget {
  const EditorialOverlayPageScope({
    super.key,
    required this.topContentInset,
    required this.bottomBarHeight,
    required super.child,
  });

  final double topContentInset;
  final double bottomBarHeight;

  static EditorialOverlayPageScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EditorialOverlayPageScope>();
  }

  static EditorialOverlayPageScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'EditorialOverlayPageScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(EditorialOverlayPageScope oldWidget) {
    return topContentInset != oldWidget.topContentInset ||
        bottomBarHeight != oldWidget.bottomBarHeight;
  }
}

double editorialOverlayTopContentInsetOf(
  BuildContext context, {
  double fallback = 0,
}) {
  return EditorialOverlayPageScope.maybeOf(context)?.topContentInset ??
      fallback;
}

double editorialOverlayBottomBarHeightOf(
  BuildContext context, {
  double fallback = 0,
}) {
  return EditorialOverlayPageScope.maybeOf(context)?.bottomBarHeight ??
      fallback;
}

class EditorialOverlayPageShell extends StatefulWidget {
  const EditorialOverlayPageShell({
    super.key,
    required this.background,
    required this.topBar,
    required this.bodyBuilder,
    this.floatingBuilder,
    this.backgroundColor,
    this.topBarPadding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
    this.topContentGap = 20,
    this.estimatedTopBarHeight = 56,
  });

  final Widget background;
  final Widget topBar;
  final EditorialOverlayBodyBuilder bodyBuilder;
  final EditorialOverlayFloatingBuilder? floatingBuilder;
  final Color? backgroundColor;
  final EdgeInsets topBarPadding;
  final double topContentGap;
  final double estimatedTopBarHeight;

  @override
  State<EditorialOverlayPageShell> createState() =>
      _EditorialOverlayPageShellState();
}

class _EditorialOverlayPageShellState extends State<EditorialOverlayPageShell> {
  late double _topBarHeight = widget.estimatedTopBarHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomBarHeight = ShellScaffoldInset.bottomBarHeightOf(context);
    final safeTopInset = MediaQuery.paddingOf(context).top;
    final topContentInset = safeTopInset +
        widget.topBarPadding.top +
        _topBarHeight +
        widget.topContentGap;

    return Material(
      color: widget.backgroundColor ?? colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: widget.background,
            ),
          ),
          Positioned.fill(
            child: EditorialOverlayPageScope(
              topContentInset: topContentInset,
              bottomBarHeight: bottomBarHeight,
              child: widget.bodyBuilder(
                context,
                topContentInset,
                bottomBarHeight,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: widget.topBarPadding,
                child: MeasureSize(
                  onChange: (size) {
                    if (!mounted || (_topBarHeight - size.height).abs() < 0.5) {
                      return;
                    }
                    setState(() {
                      _topBarHeight = size.height;
                    });
                  },
                  child: widget.topBar,
                ),
              ),
            ),
          ),
          if (widget.floatingBuilder != null)
            Positioned.fill(
              child: EditorialOverlayPageScope(
                topContentInset: topContentInset,
                bottomBarHeight: bottomBarHeight,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: widget.floatingBuilder!(context, bottomBarHeight),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
