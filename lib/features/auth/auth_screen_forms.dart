part of 'auth_screen.dart';

class _AuthFlowPanel extends StatelessWidget {
  const _AuthFlowPanel({
    required this.mode,
    required this.progress,
    required this.signInFormKey,
    required this.registerFormKey,
    required this.isBusy,
    required this.signInEmailController,
    required this.signInPasswordController,
    required this.registerNameController,
    required this.registerEmailController,
    required this.registerPasswordController,
    required this.registerConfirmPasswordController,
    required this.onForgotPasswordPressed,
    required this.onSignInPressed,
    required this.onRegisterPressed,
    required this.onGooglePressed,
    required this.onSwitchMode,
  });

  final _AuthPanelMode mode;
  final double progress;
  final GlobalKey<FormState> signInFormKey;
  final GlobalKey<FormState> registerFormKey;
  final bool isBusy;
  final TextEditingController signInEmailController;
  final TextEditingController signInPasswordController;
  final TextEditingController registerNameController;
  final TextEditingController registerEmailController;
  final TextEditingController registerPasswordController;
  final TextEditingController registerConfirmPasswordController;
  final VoidCallback onForgotPasswordPressed;
  final VoidCallback onSignInPressed;
  final VoidCallback onRegisterPressed;
  final VoidCallback onGooglePressed;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    final isRegister = mode == _AuthPanelMode.register;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FlowingHeadline(progress: progress),
        const SizedBox(height: 28),
        Form(
          key: isRegister ? registerFormKey : signInFormKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _FlowReveal(
                  progress: progress,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AuthTextField(
                      controller: registerNameController,
                      label: 'Display name',
                      hintText: 'Your name',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (!isRegister) {
                          return null;
                        }
                        final text = (value ?? '').trim();
                        if (text.length < 4) {
                          return 'Use at least 4 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                _AuthTextField(
                  controller: isRegister
                      ? registerEmailController
                      : signInEmailController,
                  label: 'Email',
                  hintText: 'hello@example.com',
                  icon: Icons.mail_outline_rounded,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.username],
                  validator: _validateEmail,
                ),
                const SizedBox(height: 18),
                _AuthTextField(
                  controller: isRegister
                      ? registerPasswordController
                      : signInPasswordController,
                  label: 'Password',
                  hintText: isRegister ? '10+ characters' : 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction:
                      isRegister ? TextInputAction.next : TextInputAction.done,
                  autofillHints: isRegister
                      ? const <String>[AutofillHints.newPassword]
                      : const <String>[AutofillHints.password],
                  validator: (value) {
                    final text = value ?? '';
                    if (isRegister && text.length < 10) {
                      return 'Use at least 10 characters';
                    }
                    if (!isRegister && text.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                _FlowReveal(
                  progress: progress,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _AuthTextField(
                      controller: registerConfirmPasswordController,
                      label: 'Confirm password',
                      hintText: 'Repeat password',
                      icon: Icons.verified_user_outlined,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (!isRegister) {
                          return null;
                        }
                        if (value != registerPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                _FlowReveal(
                  progress: 1 - progress,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _ForgotPasswordRow(
                      onForgotPasswordPressed:
                          isBusy ? null : onForgotPasswordPressed,
                    ),
                  ),
                ),
                SizedBox(height: 24 + (2 * progress)),
                _PrimaryActionButton(
                  label: isBusy
                      ? 'Please wait...'
                      : isRegister
                          ? 'Create account'
                          : 'Sign in',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: isBusy
                      ? null
                      : isRegister
                          ? onRegisterPressed
                          : onSignInPressed,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        _FlowDivider(progress: progress),
        const SizedBox(height: 20),
        _GoogleSignInButton(
          onPressed: isBusy ? null : onGooglePressed,
        ),
        const SizedBox(height: 30),
        _FlowFooterLink(
          progress: progress,
          onPressed: isBusy ? null : onSwitchMode,
        ),
      ],
    );
  }
}

class _FlowingHeadline extends StatelessWidget {
  const _FlowingHeadline({
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = textTheme.displayMedium?.copyWith(
      fontSize: 32,
      height: 1.02,
      letterSpacing: 0,
    );

    return SizedBox(
      height: 66,
      child: Stack(
        alignment: Alignment.topLeft,
        children: <Widget>[
          _FlowTextState(
            progress: 1 - progress,
            offset: -18 * progress,
            child: Text(
              'Welcome back\nto your world.',
              style: style,
            ),
          ),
          _FlowTextState(
            progress: progress,
            offset: 18 * (1 - progress),
            child: Text(
              'Start mapping\nyour world.',
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowDivider extends StatelessWidget {
  const _FlowDivider({
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    return _FlowSwapText(
      progress: progress,
      signInChild: const _AuthDivider(label: 'OR CONTINUE WITH'),
      registerChild: const _AuthDivider(label: 'OR SIGN UP WITH'),
    );
  }
}

class _FlowFooterLink extends StatelessWidget {
  const _FlowFooterLink({
    required this.progress,
    required this.onPressed,
  });

  final double progress;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _FlowSwapText(
      progress: progress,
      signInChild: _AuthFooterLink(
        text: 'New traveller?',
        action: 'Register here',
        onPressed: onPressed,
      ),
      registerChild: _AuthFooterLink(
        text: 'Already exploring?',
        action: 'Sign in',
        onPressed: onPressed,
      ),
    );
  }
}

class _FlowSwapText extends StatelessWidget {
  const _FlowSwapText({
    required this.progress,
    required this.signInChild,
    required this.registerChild,
  });

  final double progress;
  final Widget signInChild;
  final Widget registerChild;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        _FlowTextState(
          progress: 1 - progress,
          offset: -10 * progress,
          child: signInChild,
        ),
        _FlowTextState(
          progress: progress,
          offset: 10 * (1 - progress),
          child: registerChild,
        ),
      ],
    );
  }
}

class _FlowTextState extends StatelessWidget {
  const _FlowTextState({
    required this.progress,
    required this.offset,
    required this.child,
  });

  final double progress;
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: progress < 0.5,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, offset),
          child: Transform.scale(
            alignment: Alignment.centerLeft,
            scale: 0.985 + (0.015 * progress),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FlowReveal extends StatelessWidget {
  const _FlowReveal({
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return ClipRect(
      child: Align(
        heightFactor: clamped,
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - clamped)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatefulWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.textInputAction,
    required this.validator,
    this.keyboardType,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputAction textInputAction;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool obscureText;

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant _AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderRadius = BorderRadius.circular(18);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            widget.label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          textCapitalization: widget.textCapitalization,
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.08,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _fieldFillColor(colorScheme),
            hintText: widget.hintText,
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: colorScheme.outlineVariant.withValues(alpha: 0.92),
              fontSize: 15,
            ),
            prefixIcon: Icon(widget.icon, size: 20),
            prefixIconColor: colorScheme.outline.withValues(alpha: 0.62),
            suffixIcon: widget.obscureText
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    color: colorScheme.outline.withValues(alpha: 0.66),
                    onPressed: () {
                      setState(() {
                        _obscured = !_obscured;
                      });
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.58),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: colorScheme.error.withValues(alpha: 0.72),
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide(
                color: colorScheme.error.withValues(alpha: 0.82),
                width: 1.3,
              ),
            ),
            errorStyle: textTheme.labelSmall?.copyWith(
              color: colorScheme.error,
              height: 0.95,
              letterSpacing: 0,
            ),
          ),
          validator: widget.validator,
        ),
      ],
    );
  }
}

class _ForgotPasswordRow extends StatelessWidget {
  const _ForgotPasswordRow({
    required this.onForgotPasswordPressed,
  });

  final VoidCallback? onForgotPasswordPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onForgotPasswordPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: colorScheme.tertiary,
        ),
        child: const Text('Forgot Password?'),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  letterSpacing: 0.9,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
      ],
    );
  }
}

class _AuthFooterLink extends StatelessWidget {
  const _AuthFooterLink({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '$text ',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colorScheme.primary,
            ),
            child: Text(
              action,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _fieldFillColor(ColorScheme colorScheme) {
  return colorScheme.brightness == Brightness.dark
      ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.72)
      : colorScheme.surfaceContainer.withValues(alpha: 0.72);
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
