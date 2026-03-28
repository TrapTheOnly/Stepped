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
  late final AnimationController _backgroundController;

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
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isBusy = auth.isBusy;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _AnimatedBackdrop(
              controller: _backgroundController,
              colorScheme: colorScheme,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 28 + bottomInset),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _AuthHero(mode: _mode),
                      const SizedBox(height: 18),
                      _ModeSegmentControl(
                        mode: _mode,
                        onChanged: (nextMode) {
                          if (isBusy || _mode == nextMode) {
                            return;
                          }
                          setState(() {
                            _mode = nextMode;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          final key = child.key;
                          final isSignIn = key is ValueKey<_AuthPanelMode> &&
                              key.value == _AuthPanelMode.signIn;
                          final beginX = isSignIn ? -0.08 : 0.08;
                          final fade = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          );
                          return FadeTransition(
                            opacity: fade,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(beginX, 0),
                                end: Offset.zero,
                              ).animate(fade),
                              child: child,
                            ),
                          );
                        },
                        child: _mode == _AuthPanelMode.signIn
                            ? _SignInCard(
                                key: const ValueKey<_AuthPanelMode>(
                                  _AuthPanelMode.signIn,
                                ),
                                formKey: _signInFormKey,
                                isBusy: isBusy,
                                emailController: _signInEmailController,
                                passwordController: _signInPasswordController,
                                onPrimaryPressed: _onSignInPressed,
                                onGooglePressed: _onGooglePressed,
                              )
                            : _RegisterCard(
                                key: const ValueKey<_AuthPanelMode>(
                                  _AuthPanelMode.register,
                                ),
                                formKey: _registerFormKey,
                                isBusy: isBusy,
                                displayNameController: _registerNameController,
                                emailController: _registerEmailController,
                                passwordController: _registerPasswordController,
                                confirmPasswordController:
                                    _registerConfirmPasswordController,
                                onPrimaryPressed: _onRegisterPressed,
                                onGooglePressed: _onGooglePressed,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}
