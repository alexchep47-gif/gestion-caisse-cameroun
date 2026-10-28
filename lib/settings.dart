import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _currencyKey = 'default_currency';
  static const _pinHashKey = 'pin_hash';
  static const _biometricsKey = 'biometrics_enabled';

  ThemeMode themeMode = ThemeMode.system;
  String defaultCurrency = 'XAF';
  String? pinHash;
  bool biometricsEnabled = false;
  bool isLoading = true;

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  AppSettings() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey) ?? 'system';
    themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => ThemeMode.system,
    );
    defaultCurrency = prefs.getString(_currencyKey) ?? 'XAF';
    pinHash = prefs.getString(_pinHashKey);
    biometricsEnabled = prefs.getBool(_biometricsKey) ?? false;
    isLoading = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  Future<void> setDefaultCurrency(String code) async {
    defaultCurrency = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, code);
    notifyListeners();
  }

  Future<void> setPin(String? pin) async {
    final prefs = await SharedPreferences.getInstance();
    if (pin == null || pin.isEmpty) {
      pinHash = null;
      await prefs.remove(_pinHashKey);
    } else {
      pinHash = _hashPin(pin);
      await prefs.setString(_pinHashKey, pinHash!);
    }
    notifyListeners();
  }

  bool verifyPin(String pin) {
    if (pinHash == null) return true;
    return _hashPin(pin) == pinHash;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode('gcc_salt_v1_$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> setBiometricsEnabled(bool value) async {
    biometricsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricsKey, value);
    notifyListeners();
  }
}
