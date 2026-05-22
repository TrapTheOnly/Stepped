import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/frosted_squircle.dart';
import 'auth_controller.dart';

part 'auth_screen_hero.dart';
part 'auth_screen_forms.dart';
part 'auth_screen_actions.dart';
part 'auth_screen_google.dart';
part 'auth_screen_backdrop.dart';

enum _AuthPanelMode {
  signIn,
  register,
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  late final TextEditingController _signInEmailController;
  late final TextEditingController _signInPasswordController;
  late final TextEditingController _registerNameController;
  late final TextEditingController _registerEmailController;
  late final TextEditingController _registerPasswordController;
  late final TextEditingController _registerConfirmPasswordController;
  late final AnimationController _modeController;

  _AuthPanelMode _mode = _AuthPanelMode.signIn;

  @override
  void initState() {
    super.initState();
    _signInEmailController = TextEditingController();
    _signInPasswordController = TextEditingController();
    _registerNameController = TextEditingController();
    _registerEmailController = TextEditingController();
    _registerPasswordController = TextEditingController();
    _registerConfirmPasswordController = TextEditingController();
    _modeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      reverseDuration: const Duration(milliseconds: 520),
      value: 0,
    );
  }

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _modeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isBusy = auth.isBusy;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _authBackgroundGradient(colorScheme),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 560;
              final pageWidth = wide ? 430.0 : constraints.maxWidth;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: pageWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(wide ? 34 : 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: wide
                            ? Border.all(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.22),
                              )
                            : null,
                        boxShadow: wide
                            ? <BoxShadow>[
                                BoxShadow(
                                  color: colorScheme.shadow
                                      .withValues(alpha: 0.10),
                                  blurRadius: 32,
                                  offset: const Offset(0, 18),
                                ),
                              ]
                            : null,
                      ),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.only(bottom: 22 + bottomInset),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              AnimatedBuilder(
                                animation: _modeController,
                                builder: (context, child) {
                                  final progress = _authMotionCurve.transform(
                                    _modeController.value,
                                  );
                                  return _AuthHero(progress: progress);
                                },
                              ),
                              AnimatedBuilder(
                                animation: _modeController,
                                builder: (context, child) {
                                  final progress = _authMotionCurve.transform(
                                    _modeController.value,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      20,
                                      24,
                                      0,
                                    ),
                                    child: _AuthFlowPanel(
                                      mode: _mode,
                                      progress: progress,
                                      signInFormKey: _signInFormKey,
                                      registerFormKey: _registerFormKey,
                                      isBusy: isBusy,
                                      signInEmailController:
                                          _signInEmailController,
                                      signInPasswordController:
                                          _signInPasswordController,
                                      registerNameController:
                                          _registerNameController,
                                      registerEmailController:
                                          _registerEmailController,
                                      registerPasswordController:
                                          _registerPasswordController,
                                      registerConfirmPasswordController:
                                          _registerConfirmPasswordController,
                                      onForgotPasswordPressed:
                                          _onForgotPasswordPressed,
                                      onSignInPressed: _onSignInPressed,
                                      onRegisterPressed: _onRegisterPressed,
                                      onGooglePressed: _onGooglePressed,
                                      onSwitchMode: () => _setMode(
                                        _mode == _AuthPanelMode.signIn
                                            ? _AuthPanelMode.register
                                            : _AuthPanelMode.signIn,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _setMode(_AuthPanelMode mode) {
    final auth = ref.read(authControllerProvider);
    if (auth.isBusy || _mode == mode) {
      return;
    }
    _carrySharedAuthText(mode);
    setState(() {
      _mode = mode;
    });
    final target = mode == _AuthPanelMode.signIn ? 0.0 : 1.0;
    _modeController.animateTo(
      target,
      curve: Curves.linear,
    );
  }

  void _carrySharedAuthText(_AuthPanelMode nextMode) {
    if (nextMode == _AuthPanelMode.register) {
      if (_registerEmailController.text.trim().isEmpty) {
        _registerEmailController.text = _signInEmailController.text;
      }
      if (_registerPasswordController.text.isEmpty) {
        _registerPasswordController.text = _signInPasswordController.text;
      }
      return;
    }

    if (_signInEmailController.text.trim().isEmpty) {
      _signInEmailController.text = _registerEmailController.text;
    }
    if (_signInPasswordController.text.isEmpty) {
      _signInPasswordController.text = _registerPasswordController.text;
    }
  }

  Future<void> _onSignInPressed() async {
    final form = _signInFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final auth = ref.read(authControllerProvider);
    try {
      await auth.signInWithEmail(
        email: _signInEmailController.text,
        password: _signInPasswordController.text,
      );
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _onRegisterPressed() async {
    final form = _registerFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final auth = ref.read(authControllerProvider);
    try {
      await auth.registerWithEmail(
        displayName: _registerNameController.text,
        email: _registerEmailController.text,
        password: _registerPasswordController.text,
      );
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _onForgotPasswordPressed() async {
    final auth = ref.read(authControllerProvider);
    try {
      await auth.sendPasswordResetEmail(email: _signInEmailController.text);
      _showMessage(
        'If password reset is available, instructions will be sent to that email.',
      );
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _onGooglePressed() async {
    final auth = ref.read(authControllerProvider);
    try {
      await auth.signInWithGoogle();
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    _showSnackBar(message);
  }

  void _showMessage(String message) {
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(normalized),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

const _authMotionCurve = Cubic(0.20, 0.00, 0.00, 1.00);
