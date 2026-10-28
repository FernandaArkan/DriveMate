
import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../repositories/user_repository.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

class AppLockOverlay extends StatefulWidget {
  final Widget child;

  const AppLockOverlay({
    super.key,
    required this.child,
  });

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay> {
  final SecurityService _security = SecurityService.instance;
  final UserRepository _userRepo = UserRepository.instance;

  String _enteredPin = '';
  String? _errorMessage;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _preferPin = false;
  bool _hasPromptedBiometric = false;

  @override
  void initState() {
    super.initState();
    _security.addListener(_onSecurityChanged);
    _userRepo.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _security.removeListener(_onSecurityChanged);
    _userRepo.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onSecurityChanged() {
    if (!mounted) return;

    if (_security.isLocked && !_hasPromptedBiometric) {
      _hasPromptedBiometric = true;
      _enteredPin = '';
      _errorMessage = null;

      if (_security.isBiometricEnabled && !_preferPin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _triggerBiometricAuth();
          }
        });
      }
    } else if (!_security.isLocked) {
      _hasPromptedBiometric = false;
      _enteredPin = '';
      _errorMessage = null;
    }

    setState(() {});
  }

  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _triggerBiometricAuth() async {
    if (!_security.isBiometricEnabled || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final success = await _security.authenticateBiometric(
      reason: l10n.biometricPromptReason,
    );

    if (!mounted) return;

    if (success) {
      _security.unlock();
    } else if (_security.isPinSet) {
      setState(() => _preferPin = true);
    }
  }

  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();

    setState(() {
      _lockoutSeconds = seconds;
      _enteredPin = '';
    });

    _lockoutTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          if (_lockoutSeconds <= 1) {
            _lockoutSeconds = 0;
            _errorMessage = null;
            timer.cancel();
          } else {
            _lockoutSeconds--;
          }
        });
      },
    );
  }

  Future<void> _handleDigitPress(String digit) async {
    if (_lockoutSeconds > 0 ||
        _enteredPin.length >= SecurityService.minPinLength) {
      return;
    }

    final newPin = _enteredPin + digit;

    setState(() {
      _enteredPin = newPin;
      _errorMessage = null;
    });

    if (newPin.length != SecurityService.minPinLength) return;

    final result = await _security.verifyPin(newPin);
    if (!mounted) return;

    if (result.isSuccess) {
      _security.unlock();
      return;
    }

    final l10n = AppLocalizations.of(context);

    if (result.isLockedOut) {
      _startLockoutCountdown(result.lockoutSecondsRemaining);

      if (!mounted) return;

      setState(() {
        _errorMessage =
            '${l10n.pinLockoutNotice} '
            '${result.lockoutSecondsRemaining} '
            '${l10n.secondsSuffix}.';
      });
    } else {
      setState(() {
        _enteredPin = '';
        _errorMessage =
            '${l10n.pinIncorrect} ${result.remainingAttempts}';
      });
    }
  }

  void _handleBackspace() {
    if (_enteredPin.isEmpty || _lockoutSeconds > 0) return;

    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _handleLogoutEscape() async {
    final l10n = AppLocalizations.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.logoutConfirmTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.navy,
            fontSize: 18,
          ),
        ),
        content: Text(
          l10n.logoutConfirmMessage,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _userRepo.logout();
      _security.unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _userRepo.isLoggedIn &&
        _security.isSecurityActive &&
        _security.isLocked;

    return Stack(
      children: [
        Offstage(
          offstage: isLocked,
          child: widget.child,
        ),
        if (isLocked)
          PopScope(
            canPop: false,
            child: Scaffold(
              backgroundColor: const Color(0xFF07182D),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF07182D),
                      Color(0xFF0B2948),
                      Color(0xFF0E3864),
                      Color(0xFF071323),
                    ],
                    stops: [0.0, 0.35, 0.75, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final l10n = AppLocalizations.of(context);
                      final showPin = _security.isPinSet &&
                          (!_security.isBiometricEnabled || _preferPin);
                      final showBiometric =
                          _security.isBiometricEnabled && !_preferPin;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 40,
                            maxWidth: 420,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    border: Border.all(
                                      color: AppTheme.cyan.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: AppTheme.cyan,
                                    size: 42,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  l10n.appLockedTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  showPin
                                      ? l10n.enterPinToUnlock
                                      : l10n.unlockWithBiometric,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB0CDEB),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (showBiometric) ...[
                                  InkWell(
                                    onTap: _triggerBiometricAuth,
                                    borderRadius: BorderRadius.circular(50),
                                    child: Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.cyan.withValues(
                                          alpha: 0.1,
                                        ),
                                        border: Border.all(
                                          color: AppTheme.cyan.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.fingerprint_rounded,
                                        color: AppTheme.cyan,
                                        size: 52,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _triggerBiometricAuth,
                                    child: Text(
                                      l10n.unlockWithBiometric,
                                      style: const TextStyle(
                                        color: AppTheme.cyan,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (_security.isPinSet)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() => _preferPin = true);
                                      },
                                      icon: const Icon(
                                        Icons.pin_rounded,
                                        color: Color(0xFFB0CDEB),
                                      ),
                                      label: Text(
                                        l10n.unlockWithPin,
                                        style: const TextStyle(
                                          color: Color(0xFFB0CDEB),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                ],
                                if (showPin) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      SecurityService.minPinLength,
                                      (index) {
                                        final filled =
                                            index < _enteredPin.length;

                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          width: filled ? 18 : 14,
                                          height: filled ? 18 : 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: filled
                                                ? AppTheme.cyan
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: filled
                                                  ? AppTheme.cyan
                                                  : Colors.white54,
                                              width: 2,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_errorMessage != null ||
                                      _lockoutSeconds > 0)
                                    Text(
                                      _lockoutSeconds > 0
                                          ? '${l10n.pinLockoutNotice} '
                                              '$_lockoutSeconds '
                                              '${l10n.secondsSuffix}.'
                                          : _errorMessage ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFFF8B8B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  _buildKeypad(),
                                  const SizedBox(height: 20),
                                ],
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (_security.isBiometricEnabled &&
                                        _security.isPinSet &&
                                        _preferPin)
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() => _preferPin = false);
                                          _triggerBiometricAuth();
                                        },
                                        icon: const Icon(
                                          Icons.fingerprint_rounded,
                                          color: AppTheme.cyan,
                                          size: 18,
                                        ),
                                        label: Text(
                                          l10n.unlockWithBiometric,
                                          style: const TextStyle(
                                            color: AppTheme.cyan,
                                            fontSize: 13,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    TextButton.icon(
                                      onPressed: _handleLogoutEscape,
                                      icon: const Icon(
                                        Icons.logout_rounded,
                                        color: Colors.white54,
                                        size: 16,
                                      ),
                                      label: Text(
                                        l10n.logout,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeypad() {
    final row1 = _buildKeypadRow(['1', '2', '3']);
    final row2 = _buildKeypadRow(['4', '5', '6']);
    final row3 = _buildKeypadRow(['7', '8', '9']);
    final zeroButton = _buildKeypadButton('0');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row1,
        const SizedBox(height: 14),
        row2,
        const SizedBox(height: 14),
        row3,
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: _security.isBiometricEnabled
                  ? IconButton(
                      icon: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppTheme.cyan,
                        size: 32,
                      ),
                      onPressed: _triggerBiometricAuth,
                    )
                  : const SizedBox.shrink(),
            ),
            zeroButton,
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                icon: const Icon(
                  Icons.backspace_outlined,
                  color: Colors.white70,
                  size: 26,
                ),
                onPressed:
                    _enteredPin.isEmpty ? null : _handleBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildKeypadButton).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    final isDisabled = _lockoutSeconds > 0;

    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.white.withValues(
          alpha: isDisabled ? 0.03 : 0.07,
        ),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDisabled ? null : () => _handleDigitPress(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                color: isDisabled ? Colors.white30 : Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
