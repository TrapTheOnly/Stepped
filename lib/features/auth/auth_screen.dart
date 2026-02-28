import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

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
      duration: const Duration(seconds: 14),
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _AuthHero(),
                      const SizedBox(height: 20),
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
                      const SizedBox(height: 16),
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

class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              'assets/branding/stepped_monochrome_logo.png',
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              color: colorScheme.onPrimaryContainer,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Stepped',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to save every trip, track your progress, and share your adventures with friends.',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.28,
          ),
        ),
      ],
    );
  }
}

class _ModeSegmentControl extends StatelessWidget {
  const _ModeSegmentControl({
    required this.mode,
    required this.onChanged,
  });

  final _AuthPanelMode mode;
  final ValueChanged<_AuthPanelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: mode == _AuthPanelMode.signIn
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _ModeSegmentButton(
                  label: 'Sign in',
                  selected: mode == _AuthPanelMode.signIn,
                  onTap: () => onChanged(_AuthPanelMode.signIn),
                ),
              ),
              Expanded(
                child: _ModeSegmentButton(
                  label: 'Register',
                  selected: mode == _AuthPanelMode.register,
                  onTap: () => onChanged(_AuthPanelMode.register),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentButton extends StatelessWidget {
  const _ModeSegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor:
            selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    super.key,
    required this.formKey,
    required this.isBusy,
    required this.emailController,
    required this.passwordController,
    required this.onPrimaryPressed,
    required this.onGooglePressed,
  });

  final GlobalKey<FormState> formKey;
  final bool isBusy;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onGooglePressed;

  @override
  Widget build(BuildContext context) {
    return _AuthCardShell(
      title: 'Welcome back',
      subtitle: 'Pick up where your last trip ended.',
      mode: _AuthPanelMode.signIn,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isBusy ? null : onPrimaryPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(isBusy ? 'Please wait...' : 'Sign in'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onGooglePressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const _GoogleBadge(),
              label: const Text('Continue with Google'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({
    super.key,
    required this.formKey,
    required this.isBusy,
    required this.displayNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onPrimaryPressed,
    required this.onGooglePressed,
  });

  final GlobalKey<FormState> formKey;
  final bool isBusy;
  final TextEditingController displayNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onGooglePressed;

  @override
  Widget build(BuildContext context) {
    return _AuthCardShell(
      title: 'Create your account',
      subtitle: 'Start building your travel timeline in one place.',
      mode: _AuthPanelMode.register,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: displayNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.length < 2) {
                  return 'Use at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) {
                final text = value ?? '';
                if (text.length < 8) {
                  return 'Use at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              validator: (value) {
                if (value != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isBusy ? null : onPrimaryPressed,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(isBusy ? 'Please wait...' : 'Create account'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onGooglePressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const _GoogleBadge(),
              label: const Text('Continue with Google'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCardShell extends StatelessWidget {
  const _AuthCardShell({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.child,
  });

  final String title;
  final String subtitle;
  final _AuthPanelMode mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSignIn = mode == _AuthPanelMode.signIn;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSignIn ? 30 : 22),
        border: Border.all(
          color: isSignIn
              ? colorScheme.outlineVariant.withValues(alpha: 0.44)
              : colorScheme.secondary.withValues(alpha: 0.28),
        ),
        color: isSignIn
            ? colorScheme.surface.withValues(alpha: 0.88)
            : colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.16),
            blurRadius: 42,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

String? _validateEmail(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return 'Email is required';
  }
  const emailPattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$';
  if (!RegExp(emailPattern).hasMatch(text)) {
    return 'Enter a valid email';
  }
  return null;
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

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
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -120 + (wobble * 34),
                left: -70 + (wobble * 26),
                child: _Orb(
                  diameter: 270,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                ),
              ),
              Positioned(
                top: 180 - (wobble * 20),
                right: -90 + (wobble * 32),
                child: _Orb(
                  diameter: 220,
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                bottom: -130 + (wobble * 24),
                left: 30 - (wobble * 20),
                child: _Orb(
                  diameter: 260,
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.54),
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
              color: color.withValues(alpha: 0.32),
              blurRadius: 70,
              spreadRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
