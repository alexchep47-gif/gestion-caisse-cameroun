import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'l10n.dart';
import 'settings.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    required this.settings,
    required this.onUnlocked,
    super.key,
  });

  final AppSettings settings;
  final VoidCallback onUnlocked;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final controller = TextEditingController();
  String? error;
  String? biometricMessage;
  bool isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    if (widget.settings.biometricsEnabled && !kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
    }
  }

  Future<void> _tryBiometrics() async {
    if (isAuthenticating || kIsWeb || !widget.settings.biometricsEnabled) {
      return;
    }

    final t = L10n(widget.settings.localeCode);
    setState(() {
      isAuthenticating = true;
      biometricMessage = null;
    });

    try {
      final auth = LocalAuthentication();
      if (!await auth.canCheckBiometrics) {
        if (mounted) {
          setState(() => biometricMessage = t.biometricNotAvailable);
        }
        return;
      }

      final authenticated = await auth.authenticate(
        localizedReason: t.biometricUnlockReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (authenticated) {
        widget.onUnlocked();
      } else {
        setState(() => biometricMessage = t.biometricCanceled);
      }
    } on PlatformException catch (exception) {
      if (mounted) {
        setState(() => biometricMessage = t.biometricError(exception.code));
      }
    } catch (_) {
      if (mounted) setState(() => biometricMessage = t.biometricFailure);
    } finally {
      if (mounted) setState(() => isAuthenticating = false);
    }
  }

  void _submit() {
    if (widget.settings.verifyPin(controller.text)) {
      widget.onUnlocked();
    } else {
      setState(() {
        error = L10n(widget.settings.localeCode).wrongPin;
        controller.clear();
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n(widget.settings.localeCode);

    return Scaffold(
      backgroundColor: const Color(0xff0f766e),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    t.pinCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.enterPin,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      errorText: error,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff0f766e),
                    ),
                    onPressed: _submit,
                    child: Text(t.unlock),
                  ),
                  if (widget.settings.biometricsEnabled && !kIsWeb) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: isAuthenticating ? null : _tryBiometrics,
                      icon: isAuthenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fingerprint, color: Colors.white),
                      label: Text(
                        isAuthenticating
                            ? t.biometricChecking
                            : t.useBiometrics,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (biometricMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        biometricMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
