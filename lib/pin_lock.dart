import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
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
  bool biometricsTried = false;

  @override
  void initState() {
    super.initState();
    if (widget.settings.biometricsEnabled && !kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
    }
  }

  Future<void> _tryBiometrics() async {
    if (biometricsTried) return;
    biometricsTried = true;
    try {
      final auth = LocalAuthentication();
      final can = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!can) return;
      final ok = await auth.authenticate(
        localizedReason: 'Déverrouiller Gestion Caisse',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      // Biometrics unavailable or cancelled — fall back to PIN
    }
  }

  void _submit() {
    if (widget.settings.verifyPin(controller.text)) {
      widget.onUnlocked();
    } else {
      setState(() {
        error = 'Code PIN incorrect';
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
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Code PIN',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entrez votre code pour accéder à la caisse',
                    style: TextStyle(color: Colors.white70),
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xff0f766e),
                    ),
                    onPressed: _submit,
                    child: const Text('Déverrouiller'),
                  ),
                  if (widget.settings.biometricsEnabled && !kIsWeb) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _tryBiometrics,
                      icon: const Icon(Icons.fingerprint, color: Colors.white),
                      label: const Text(
                        'Utiliser la biométrie',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
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
