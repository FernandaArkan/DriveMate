import 'package:flutter/material.dart';

import '../repositories/user_repository.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'andi@email.com');
  final _passwordController = TextEditingController(text: '123456');

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.instance.isBiometricAvailable();
    if (mounted) {
      setState(() => _canUseBiometrics = available);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await UserRepository.instance.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showMessage(
        'Email/No. HP atau password salah. Coba: andi@email.com / 123456',
        isError: true,
      );
    }
  }

  Future<void> _loginWithBiometrics() async {
    final authenticated = await BiometricService.instance.authenticate();
    if (authenticated && mounted) {
      final user = UserRepository.instance.currentUser;
      if (user != null) {
        await UserRepository.instance.login(user.email, user.passwordHash ?? '123456');
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } else if (mounted) {
      _showMessage('Autentikasi biometrik tidak berhasil atau dibatalkan.');
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.danger : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CAFC6),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFFB6CBE2),
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF10243B),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF203954),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppTheme.primary,
          width: 1.5,
        ),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFFF9AAB),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF061323),
              Color(0xFF07182D),
              Color(0xFF020914),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 26,
              vertical: 18,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/',
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary
                                    .withValues(alpha: 0.2),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            color: AppTheme.cyan,
                            size: 52,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'DriveMate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Login ke Akun Anda',
                          style: TextStyle(
                            color: Color(0xFFD5E4F5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Email atau No. HP',
                      icon: Icons.mail_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email atau nomor HP wajib diisi.';
                      }
                      if (value.trim().length < 4) {
                        return 'Masukkan email atau nomor HP yang valid.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFFB6CBE2),
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password wajib diisi.';
                      }
                      if (value.length < 5) {
                        return 'Password minimal 6 karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 34,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: AppTheme.primary,
                          side: const BorderSide(
                            color: Color(0xFF9CB6D4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Ingat saya',
                          style: TextStyle(
                            color: Color(0xFFD5E4F5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _showMessage(
                            'Password default: 123456 (Akun: andi@email.com)',
                          );
                        },
                        child: const Text(
                          'Lupa password?',
                          style: TextStyle(
                            color: AppTheme.cyan,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (_canUseBiometrics) ...[
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: _loginWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded, size: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF1A395E),
                            foregroundColor: AppTheme.cyan,
                            minimumSize: const Size(52, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(color: Color(0xFF29415D)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'atau masuk dengan',
                          style: TextStyle(
                            color: Color(0xFF9CAFC6),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Color(0xFF29415D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _socialButton(
                          icon: Icons.g_mobiledata_rounded,
                          label: 'Google',
                          onTap: () {
                            _showMessage(
                              'Login Google menggunakan API OAuth backend.',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _socialButton(
                          icon: Icons.apple,
                          label: 'Apple',
                          onTap: () {
                            _showMessage(
                              'Apple Sign-In tersedia di iOS dengan Apple Developer ID.',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          'Belum punya akun? ',
                          style: TextStyle(
                            color: Color(0xFF9CAFC6),
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Daftar',
                            style: TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(
          color: Color(0xFF35506D),
        ),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }
}
