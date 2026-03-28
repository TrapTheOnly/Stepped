part of 'auth_screen.dart';

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
      eyebrow: 'RETURNING TRAVELLER',
      child: Form(
        key: formKey,
        child: AutofillGroup(
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
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'At least 10 characters',
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
              _PrimaryActionButton(
                label: isBusy ? 'Please wait...' : 'Sign in',
                onPressed: isBusy ? null : onPrimaryPressed,
              ),
              const SizedBox(height: 10),
              _GoogleSignInButton(
                onPressed: isBusy ? null : onGooglePressed,
              ),
            ],
          ),
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
      eyebrow: 'NEW EXPLORER',
      child: Form(
        key: formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: displayNameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'Forever username',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.length < 4) {
                    return 'Use at least 4 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Use at least 10 characters',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.length < 10) {
                    return 'Use at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  hintText: 'Repeat your password',
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
              _PrimaryActionButton(
                label: isBusy ? 'Please wait...' : 'Create account',
                onPressed: isBusy ? null : onPrimaryPressed,
              ),
              const SizedBox(height: 10),
              _GoogleSignInButton(
                onPressed: isBusy ? null : onGooglePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthCardShell extends StatelessWidget {
  const _AuthCardShell({
    required this.eyebrow,
    required this.child,
  });

  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 38,
      blurSigma: 22,
      color: colorScheme.surface.withValues(alpha: 0.76),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  letterSpacing: 1.4,
                ),
          ),
          const SizedBox(height: 6),
          child,
        ],
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
