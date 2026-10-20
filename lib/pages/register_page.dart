import 'package:flutter/material.dart';
import '../repositories/user_repository.dart';
import '../theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await UserRepository.instance.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran berhasil! Selamat datang di DriveMate.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran gagal. Silakan coba kembali.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Daftar Akun Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kelola semua kendaraan Anda dengan mudah',
                    style: TextStyle(
                      color: Color(0xFFD5E4F5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Nama Lengkap
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: 'Nama Lengkap',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nama lengkap wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: 'Email Aktif',
                      icon: Icons.mail_outline_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                      if (!v.contains('@') || !v.contains('.')) return 'Format email tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // No HP
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: 'Nomor HP (WhatsApp)',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (v) => v == null || v.trim().length < 9 ? 'Nomor HP minimal 9 digit' : null,
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: 'Password (min. 6 karakter)',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFFB6CBE2),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'Password minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 14),

                  // Konfirmasi Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: 'Ulangi Password',
                      icon: Icons.lock_clock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFFB6CBE2),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) return 'Password tidak cocok';
                      return null;
                    },
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _register,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Daftar Sekarang',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Center(
                    child: Wrap(
                      children: [
                        const Text(
                          'Sudah punya akun? ',
                          style: TextStyle(color: Color(0xFF9CAFC6), fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppTheme.cyan,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
