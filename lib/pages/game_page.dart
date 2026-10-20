import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late final AnimationController _gameLoopController;

  int _score = 0;
  int _lives = 3;
  int _level = 1;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // Player physics
  double _playerY = 0.0; // 0 = di tanah, > 0 = melompat
  double _playerVelocity = 0.0;
  final double _gravity = -0.55;
  final double _jumpForce = 9.5;

  // Obstacles
  double _obstacleX = 350.0;
  final double _obstacleWidth = 35.0;
  final double _obstacleHeight = 35.0;

  @override
  void initState() {
    super.initState();
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateGame);

    _startGame();
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _lives = 3;
      _level = 1;
      _playerY = 0.0;
      _playerVelocity = 0.0;
      _obstacleX = 400.0;
      _isGameOver = false;
      _isPlaying = true;
    });
    _gameLoopController.repeat();
  }

  void _jump() {
    if (_isGameOver) return;
    if (_playerY == 0.0) {
      setState(() {
        _playerVelocity = _jumpForce;
      });
    }
  }

  void _updateGame() {
    if (!_isPlaying || _isGameOver) return;

    setState(() {
      // 1. Fisika lompat pemain
      _playerY += _playerVelocity;
      _playerVelocity += _gravity;

      if (_playerY <= 0.0) {
        _playerY = 0.0;
        _playerVelocity = 0.0;
      }

      // 2. Pergerakan obstacle mendekat
      final speed = 4.0 + (_level * 0.8);
      _obstacleX -= speed;

      // Obstacle melewati pemain -> skor bertambah
      if (_obstacleX < -40.0) {
        _obstacleX = 380.0 + Random().nextDouble() * 120.0;
        _score += 100;
        if (_score % 500 == 0) {
          _level++;
        }
      }

      // 3. Deteksi Tabrakan (AABB Collision)
      // Pemain di X = 60..110, Y = _playerY
      // Obstacle di X = _obstacleX.._obstacleX + 35, Y = 0..35
      final playerXStart = 60.0;
      final playerXEnd = 110.0;
      final obstacleXEnd = _obstacleX + _obstacleWidth;

      final isOverlapX = _obstacleX < playerXEnd && obstacleXEnd > playerXStart;
      final isOverlapY = _playerY < _obstacleHeight;

      if (isOverlapX && isOverlapY) {
        // Tabrakan!
        _lives--;
        _obstacleX = 400.0; // Reset rintangan ke belakang
        if (_lives <= 0) {
          _isGameOver = true;
          _isPlaying = false;
          _gameLoopController.stop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF63B4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Vehicle Runner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _jump,
        child: SafeArea(
          child: Column(
            children: [
              // Score & Status Bar (Mockup Layar 10)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Score Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text('Score', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text(
                            '$_score',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hearts Box
                    Row(
                      children: List.generate(
                        3,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            index < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: Colors.redAccent,
                            size: 26,
                          ),
                        ),
                      ),
                    ),

                    // Level Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text('Level', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text(
                            '$_level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Game Canvas
              Expanded(
                child: Stack(
                  children: [
                    // Background Langit & Kota
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GameBackgroundPainter(),
                      ),
                    ),

                    // Mobil Pemain (Merah)
                    Positioned(
                      left: 60,
                      bottom: 110 + _playerY,
                      child: Container(
                        width: 55,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_filled_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                    // Obstacle Rintangan (Cone Lalu Lintas)
                    Positioned(
                      left: _obstacleX,
                      bottom: 110,
                      child: Container(
                        width: _obstacleWidth,
                        height: _obstacleHeight,
                        decoration: BoxDecoration(
                          color: AppTheme.warning,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                    ),

                    // Jalan Raya & Rumput
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 110,
                      child: Column(
                        children: [
                          // Jalan Aspal Abu-abu
                          Container(
                            height: 60,
                            color: const Color(0xFF37474F),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                10,
                                (i) => Container(
                                  width: 20,
                                  height: 4,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          // Tanah & Rumput
                          Expanded(
                            child: Container(
                              color: const Color(0xFF689F38),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.touch_app_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tap untuk melompat',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Game Over Overlay
                    if (_isGameOver)
                      Container(
                        color: Colors.black.withValues(alpha: 0.7),
                        alignment: Alignment.center,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sentiment_dissatisfied_rounded, size: 54, color: AppTheme.danger),
                              const SizedBox(height: 12),
                              const Text(
                                'Game Over!',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Skor Akhir: $_score poin',
                                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _startGame,
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('Main Lagi'),
                              ),
                            ],
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
    );
  }
}

class _GameBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Gedung-gedung siluet di kejauhan
    final buildingPaint = Paint()..color = const Color(0xFF90CAF9);
    final baseY = size.height - 110;

    canvas.drawRect(Rect.fromLTWH(20, baseY - 90, 45, 90), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(80, baseY - 130, 55, 130), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(150, baseY - 80, 40, 80), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(205, baseY - 150, 60, 150), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(280, baseY - 100, 50, 100), buildingPaint);
    canvas.drawRect(Rect.fromLTWH(345, baseY - 120, 50, 120), buildingPaint);

    // Awan putih
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(size.width * 0.25, 60), 22, cloudPaint);
    canvas.drawCircle(Offset(size.width * 0.32, 50), 30, cloudPaint);
    canvas.drawCircle(Offset(size.width * 0.40, 60), 24, cloudPaint);

    canvas.drawCircle(Offset(size.width * 0.75, 90), 20, cloudPaint);
    canvas.drawCircle(Offset(size.width * 0.82, 80), 26, cloudPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
