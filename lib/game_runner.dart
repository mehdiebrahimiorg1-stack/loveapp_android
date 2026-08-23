import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class GameRunnerScreen extends StatefulWidget {
  const GameRunnerScreen({super.key});
  @override
  State<GameRunnerScreen> createState() => _GameRunnerScreenState();
}

class _GameRunnerScreenState extends State<GameRunnerScreen>
    with TickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isDead = false;
  int _score = 0;
  int _lives = 3;
  double _speed = 1.0;

  // فیزیک کاراکتر
  double _girlJumpOffset = 0.0; // px از زمین به بالا (مثبت = بالاتر)
  bool _isJumping = false;
  double _jumpVelocity = 0.0;

  List<_Obstacle> _obstacles = [];
  double _obstacleTimer = 0;
  double _nextObstacleIn = 2.0;

  late AnimationController _runController;
  late AnimationController _bgController;
  late AnimationController _hitController;

  List<_Cloud> _clouds = [];
  List<_Star> _stars = [];

  Timer? _gameTimer;
  Timer? _scoreTimer;

  // ثابت‌های فیزیک (px)
  static const double _gravity = 1.2;
  static const double _jumpForce = -22.0;

  @override
  void initState() {
    super.initState();
    _runController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..repeat(reverse: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _hitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initClouds();
    _initStars();
  }

  void _initClouds() {
    _clouds = List.generate(6, (i) => _Cloud(
      x: i * 0.18 + Random().nextDouble() * 0.08,
      y: 0.05 + Random().nextDouble() * 0.22,
      scale: 0.5 + Random().nextDouble() * 0.8,
    ));
  }

  void _initStars() {
    _stars = List.generate(25, (i) => _Star(
      x: Random().nextDouble(),
      y: Random().nextDouble() * 0.55,
      size: 1.0 + Random().nextDouble() * 2.5,
    ));
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isDead = false;
      _score = 0;
      _lives = 3;
      _speed = 1.0;
      _girlJumpOffset = 0.0;
      _isJumping = false;
      _jumpVelocity = 0.0;
      _obstacles = [];
      _obstacleTimer = 0;
      _nextObstacleIn = 2.0;
    });
    _hitController.reset();

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);

    _scoreTimer?.cancel();
    _scoreTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isPlaying && !_isDead && mounted) {
        setState(() {
          _score++;
          _speed = 1.0 + _score * 0.004;
        });
      }
    });
  }

  void _gameLoop(Timer timer) {
    if (!_isPlaying || _isDead || !mounted) return;

    setState(() {
      // فیزیک پریدن
      if (_isJumping) {
        _jumpVelocity += _gravity;
        _girlJumpOffset -= _jumpVelocity;
        if (_girlJumpOffset <= 0) {
          _girlJumpOffset = 0;
          _isJumping = false;
          _jumpVelocity = 0;
        }
      }

      // ابرها
      for (final c in _clouds) {
        c.x -= 0.0008 * _speed;
        if (c.x < -0.25) {
          c.x = 1.1 + Random().nextDouble() * 0.2;
          c.y = 0.05 + Random().nextDouble() * 0.22;
        }
      }

      // تولید مانع
      _obstacleTimer += 0.016 * _speed;
      if (_obstacleTimer >= _nextObstacleIn) {
        _obstacleTimer = 0;
        _nextObstacleIn = 1.4 + Random().nextDouble() * 1.8;
        _obstacles.add(_Obstacle(x: 1.05, type: Random().nextInt(3)));
      }

      // حرکت موانع
      for (final o in _obstacles) {
        o.x -= 0.007 * _speed;
      }
      _obstacles.removeWhere((o) => o.x < -0.15);

      // برخورد
      for (final o in _obstacles) {
        if (_checkCollision(o)) {
          _lives--;
          _obstacles.remove(o);
          _hitController.forward(from: 0).then((_) => _hitController.reverse());
          if (_lives <= 0) _gameOver();
          break;
        }
      }
    });
  }

  bool _checkCollision(_Obstacle obs) {
    // کاراکتر: x=0.10 تا 0.22، ارتفاعش 80px، پریدن = _girlJumpOffset
    const girlLeft = 0.10;
    const girlRight = 0.22;
    const girlHeightFactor = 0.13; // نسبت به height صفحه

    final obsLeft = obs.x + 0.01;
    final obsRight = obs.x + 0.08;

    // مانع پرنده بالاتره
    final obsTopFactor = obs.type == 2 ? 0.10 : 0.0;

    // وقتی پریده، girlJumpOffset > 0 یعنی از زمین فاصله داره
    // اگه بالاتر از مانع باشه، برخورد نیست
    final girlTopPx = _girlJumpOffset + 80; // px از پایین

    if (obs.type == 2 && girlTopPx > 50) return false; // از زیر پرنده رد میشه

    return girlRight > obsLeft &&
        girlLeft < obsRight &&
        _girlJumpOffset < 55; // اگه بلند پریده باشه، رد میشه
  }

  void _jump() {
    if (!_isPlaying) {
      _startGame();
      return;
    }
    if (!_isJumping && _girlJumpOffset <= 0) {
      setState(() {
        _isJumping = true;
        _jumpVelocity = _jumpForce;
      });
    }
  }

  void _gameOver() {
    setState(() => _isDead = true);
    _gameTimer?.cancel();
    _scoreTimer?.cancel();
    _hitController.forward();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _scoreTimer?.cancel();
    _runController.dispose();
    _bgController.dispose();
    _hitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // ارتفاع زمین از پایین صفحه
    final groundFromBottom = size.height * 0.25;
    // پایه کاراکتر از پایین صفحه
    final girlBottom = groundFromBottom + _girlJumpOffset;

    return Scaffold(
      body: GestureDetector(
        onTap: _jump,
        child: Stack(
          children: [
            // پس‌زمینه
            AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => CustomPaint(
                painter: _BackgroundPainter(_bgController.value, _clouds, _stars),
                size: size,
              ),
            ),

            // زمین
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (_, __) => CustomPaint(
                  painter: _GroundPainter(_bgController.value * _speed * 2),
                  size: Size(size.width, groundFromBottom),
                ),
              ),
            ),

            // موانع
            ...(_obstacles.map((obs) {
              final obsH = obs.type == 1 ? 70.0 : obs.type == 2 ? 50.0 : 55.0;
              return Positioned(
                left: obs.x * size.width,
                bottom: groundFromBottom - 4,
                child: _ObstacleWidget(type: obs.type, h: obsH),
              );
            })),

            // کاراکتر دختر — دقیقاً روی زمین
            AnimatedBuilder(
              animation: Listenable.merge([_runController, _hitController]),
              builder: (_, __) {
                final shake = _hitController.value > 0
                    ? sin(_hitController.value * pi * 8) * 6
                    : 0.0;
                final opacity = _hitController.value > 0
                    ? (sin(_hitController.value * pi * 6) > 0 ? 1.0 : 0.3)
                    : 1.0;
                return Positioned(
                  left: size.width * 0.10 + shake,
                  bottom: girlBottom,
                  child: Opacity(
                    opacity: opacity,
                    child: _GirlCharacter(
                      isJumping: _isJumping,
                      runValue: _runController.value,
                      isDead: _isDead,
                    ),
                  ),
                );
              },
            ),

            // HUD
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('امتیاز: $_score',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      children: List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          i < _lives ? Icons.favorite : Icons.favorite_border,
                          color: i < _lives ? Colors.red : Colors.white30,
                          size: 24,
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),

            // صفحه شروع
            if (!_isPlaying && !_isDead) _buildStartScreen(),

            // Game Over
            if (_isDead) _buildGameOverScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏃‍♀️', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('دختر دونده',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.purple, blurRadius: 10)])),
            const SizedBox(height: 10),
            Text('برای شروع ضربه بزن!',
                style: TextStyle(
                    fontSize: 16, color: Colors.white.withOpacity(0.85))),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text('💡 برای پریدن روی صفحه بزن',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.4), blurRadius: 30)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('💔', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            const Text('بازی تموم شد!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple)),
            const SizedBox(height: 16),
            Text('امتیاز: $_score',
                style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.bold, color: Colors.pink)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('دوباره! 🏃‍♀️',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================
// کاراکتر دختر
// ============================================
class _GirlCharacter extends StatelessWidget {
  final bool isJumping;
  final double runValue;
  final bool isDead;
  const _GirlCharacter({required this.isJumping, required this.runValue, required this.isDead});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _GirlPainter(isJumping: isJumping, runValue: runValue, isDead: isDead),
        size: const Size(54, 82),
      );
}

class _GirlPainter extends CustomPainter {
  final bool isJumping, isDead;
  final double runValue;
  _GirlPainter({required this.isJumping, required this.runValue, required this.isDead});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isDead) {
      canvas.save();
      canvas.translate(w / 2, h / 2);
      canvas.rotate(pi / 2);
      canvas.translate(-w / 2, -h / 2);
    }

    final leg = isJumping ? 0.0 : sin(runValue * pi) * 9.0;

    // سایه زیر کاراکتر
    canvas.drawOval(
      Rect.fromLTWH(w * 0.1, h * 0.94, w * 0.8, h * 0.06),
      Paint()..color = Colors.black.withOpacity(0.18),
    );

    // کفش‌ها
    final shoe = Paint()..color = const Color(0xFF4E342E);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.86 + leg, w * 0.24, h * 0.11), const Radius.circular(5)), shoe);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.52, h * 0.86 - leg, w * 0.24, h * 0.11), const Radius.circular(5)), shoe);

    // جوراب سفید
    final sock = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.78 + leg, w * 0.18, h * 0.1), const Radius.circular(3)), sock);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.54, h * 0.78 - leg, w * 0.18, h * 0.1), const Radius.circular(3)), sock);

    // پاها (پوست)
    final skin = Paint()..color = const Color(0xFFFFCC80);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.65 + leg, w * 0.18, h * 0.16), const Radius.circular(4)), skin);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.56, h * 0.65 - leg, w * 0.18, h * 0.16), const Radius.circular(4)), skin);

    // دامن پُر
    final skirt = Paint()..color = const Color(0xFFE91E63);
    final skirtPath = Path()
      ..moveTo(w * 0.18, h * 0.54)
      ..lineTo(w * 0.08, h * 0.70)
      ..quadraticBezierTo(w * 0.50, h * 0.76, w * 0.92, h * 0.70)
      ..lineTo(w * 0.80, h * 0.54)
      ..close();
    canvas.drawPath(skirtPath, skirt);
    // تزئین دامن
    canvas.drawPath(
      skirtPath,
      Paint()
        ..color = const Color(0xFFF06292)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // بدن
    final body = Paint()..color = const Color(0xFFFF80AB);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, h * 0.34, w * 0.50, h * 0.24), const Radius.circular(10)), body);

    // کمربند
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.52, w * 0.54, h * 0.05), const Radius.circular(3)),
        Paint()..color = const Color(0xFFC2185B));

    // دست‌ها
    final arm = Paint()..color = skin.color;
    final armSwing = isJumping ? -8.0 : cos(runValue * pi) * 9.0;
    // دست چپ
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.35 + armSwing, w * 0.17, h * 0.2), const Radius.circular(6)), arm);
    // دست راست
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.76, h * 0.35 - armSwing, w * 0.17, h * 0.2), const Radius.circular(6)), arm);
    // مشت‌ها
    canvas.drawCircle(Offset(w * 0.14, h * 0.55 + armSwing), w * 0.09, arm);
    canvas.drawCircle(Offset(w * 0.84, h * 0.55 - armSwing), w * 0.09, arm);

    // گردن
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.40, h * 0.22, w * 0.18, h * 0.14), const Radius.circular(4)),
        Paint()..color = const Color(0xFFFFB74D));

    // صورت
    final face = Paint()..color = const Color(0xFFFFB74D);
    canvas.drawOval(Rect.fromLTWH(w * 0.20, h * 0.03, w * 0.58, h * 0.24), face);

    // موهای بلوند فرفری — پشت
    final hair = Paint()..color = const Color(0xFFFFD700);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.60, h * 0.04, w * 0.25, h * 0.38), const Radius.circular(12)), hair);
    // فرفری پشت
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(w * (0.68 + i * 0.05), h * (0.40 + i * 0.03)), w * 0.1, hair);
    }

    // موهای بالا
    canvas.drawOval(Rect.fromLTWH(w * 0.16, h * 0.0, w * 0.66, h * 0.14), hair);
    // فرفری‌های روی سر
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(w * (0.14 + i * 0.13), h * (0.01 + (i % 2) * 0.05)),
        w * 0.1,
        hair,
      );
    }
    // موهای کنار
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.06, w * 0.14, h * 0.16), hair);

    // گوش‌ها
    canvas.drawCircle(Offset(w * 0.20, h * 0.14), w * 0.07, face);
    canvas.drawCircle(Offset(w * 0.78, h * 0.14), w * 0.07, face);

    // چشم‌ها (بزرگ‌تر و زیباتر)
    // سایه چشم
    canvas.drawOval(Rect.fromLTWH(w * 0.30, h * 0.09, w * 0.14, h * 0.09),
        Paint()..color = const Color(0xFF7B1FA2).withOpacity(0.3));
    canvas.drawOval(Rect.fromLTWH(w * 0.55, h * 0.09, w * 0.14, h * 0.09),
        Paint()..color = const Color(0xFF7B1FA2).withOpacity(0.3));

    // چشم اصلی
    canvas.drawOval(Rect.fromLTWH(w * 0.31, h * 0.09, w * 0.13, h * 0.09),
        Paint()..color = const Color(0xFF1A237E));
    canvas.drawOval(Rect.fromLTWH(w * 0.56, h * 0.09, w * 0.13, h * 0.09),
        Paint()..color = const Color(0xFF1A237E));

    // سفیدی چشم
    canvas.drawCircle(Offset(w * 0.35, h * 0.12), w * 0.03, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.60, h * 0.12), w * 0.03, Paint()..color = Colors.white);

    // مژه
    final lash = Paint()..color = Colors.black..strokeWidth = 1.2..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(w * (0.31 + i * 0.04), h * 0.09),
        Offset(w * (0.29 + i * 0.04), h * 0.06),
        lash,
      );
      canvas.drawLine(
        Offset(w * (0.57 + i * 0.04), h * 0.09),
        Offset(w * (0.55 + i * 0.04), h * 0.06),
        lash,
      );
    }

    // گونه‌های صورتی
    canvas.drawCircle(Offset(w * 0.28, h * 0.18),
        w * 0.08, Paint()..color = Colors.pink.withOpacity(0.35));
    canvas.drawCircle(Offset(w * 0.70, h * 0.18),
        w * 0.08, Paint()..color = Colors.pink.withOpacity(0.35));

    // لبخند
    canvas.drawArc(
      Rect.fromLTWH(w * 0.37, h * 0.16, w * 0.24, h * 0.08),
      0, pi, false,
      Paint()..color = const Color(0xFFD32F2F)..style = PaintingStyle.stroke..strokeWidth = 1.8,
    );

    // دکمه روی لباس
    canvas.drawCircle(Offset(w * 0.50, h * 0.41), w * 0.05, Paint()..color = Colors.white70);
    canvas.drawCircle(Offset(w * 0.50, h * 0.47), w * 0.05, Paint()..color = Colors.white70);

    if (isDead) canvas.restore();
  }

  @override
  bool shouldRepaint(_GirlPainter old) =>
      old.isJumping != isJumping || old.runValue != runValue || old.isDead != isDead;
}

// ============================================
// موانع
// ============================================
class _ObstacleWidget extends StatelessWidget {
  final int type;
  final double h;
  const _ObstacleWidget({required this.type, required this.h});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _ObstaclePainter(type: type),
        size: Size(48, h),
      );
}

class _ObstaclePainter extends CustomPainter {
  final int type;
  _ObstaclePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (type == 0) {
      // سنگ بزرگ
      final p = Paint()..color = const Color(0xFF607D8B);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, h * 0.25, w, h * 0.75), const Radius.circular(10)), p);
      canvas.drawOval(Rect.fromLTWH(w * 0.05, h * 0.1, w * 0.9, h * 0.4),
          Paint()..color = const Color(0xFF90A4AE));
      // ترک
      canvas.drawLine(Offset(w * 0.4, h * 0.3), Offset(w * 0.55, h * 0.7),
          Paint()..color = const Color(0xFF455A64)..strokeWidth = 1.5);
    } else if (type == 1) {
      // کاکتوس
      final p = Paint()..color = const Color(0xFF2E7D32);
      final dark = Paint()..color = const Color(0xFF1B5E20);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.33, 0, w * 0.33, h), const Radius.circular(6)), p);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, h * 0.28, w * 0.38, h * 0.2), const Radius.circular(6)), p);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.62, h * 0.38, w * 0.38, h * 0.2), const Radius.circular(6)), p);
      // خارها
      for (int i = 0; i < 4; i++) {
        canvas.drawLine(Offset(w * 0.33, h * (0.1 + i * 0.22)),
            Offset(w * 0.2, h * (0.08 + i * 0.22)), dark..strokeWidth = 2);
        canvas.drawLine(Offset(w * 0.67, h * (0.1 + i * 0.22)),
            Offset(w * 0.8, h * (0.08 + i * 0.22)), dark..strokeWidth = 2);
      }
    } else {
      // پرنده (بالاتر از زمین)
      final p = Paint()..color = const Color(0xFF6A1B9A);
      // بدن
      canvas.drawOval(Rect.fromLTWH(w * 0.15, h * 0.15, w * 0.7, h * 0.55), p);
      // بال چپ
      final w1 = Path()
        ..moveTo(w * 0.15, h * 0.35)
        ..quadraticBezierTo(0, 0, w * 0.3, h * 0.25);
      canvas.drawPath(w1, p);
      // بال راست
      final w2 = Path()
        ..moveTo(w * 0.85, h * 0.35)
        ..quadraticBezierTo(w, 0, w * 0.7, h * 0.25);
      canvas.drawPath(w2, p);
      // منقار
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.82, h * 0.40)
          ..lineTo(w, h * 0.45)
          ..lineTo(w * 0.82, h * 0.55),
        Paint()..color = const Color(0xFFFF9800),
      );
      // چشم
      canvas.drawCircle(Offset(w * 0.70, h * 0.35), w * 0.09, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(w * 0.72, h * 0.36), w * 0.05, Paint()..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(_ObstaclePainter old) => old.type != type;
}

// ============================================
// پس‌زمینه
// ============================================
class _BackgroundPainter extends CustomPainter {
  final double t;
  final List<_Cloud> clouds;
  final List<_Star> stars;
  _BackgroundPainter(this.t, this.clouds, this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF0D0221),
        const Color(0xFF3A0068),
        const Color(0xFF7B0082),
        const Color(0xFFE91E63),
      ],
    );
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = grad.createShader(Offset.zero & size));

    // ستاره‌ها
    for (final s in stars) {
      final op = 0.3 + 0.7 * sin((t + s.x * 3) * 2 * pi);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height),
          s.size, Paint()..color = Colors.white.withOpacity(op));
    }

    // ماه
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.1), 28,
        Paint()..color = const Color(0xFFFFF9C4));
    canvas.drawCircle(Offset(size.width * 0.90, size.height * 0.08), 22,
        Paint()..color = const Color(0xFF3A0068));

    // ابرها
    for (final c in clouds) {
      _drawCloud(canvas, size, c);
    }
  }

  void _drawCloud(Canvas canvas, Size size, _Cloud cloud) {
    final p = Paint()..color = Colors.white.withOpacity(0.12);
    final cx = cloud.x * size.width;
    final cy = cloud.y * size.height;
    final r = 22.0 * cloud.scale;
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx + r * 0.9, cy - r * 0.2), r * 0.72, p);
    canvas.drawCircle(Offset(cx - r * 0.85, cy - r * 0.1), r * 0.62, p);
    canvas.drawCircle(Offset(cx + r * 1.55, cy + r * 0.1), r * 0.58, p);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.t != t;
}

// ============================================
// زمین
// ============================================
class _GroundPainter extends CustomPainter {
  final double offset;
  _GroundPainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    // چمن
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height * 0.18),
          const Radius.circular(0)),
      Paint()..color = const Color(0xFF2E7D32),
    );
    // خاک
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.82),
      Paint()..color = const Color(0xFF5D4037),
    );
    // خطوط چمن متحرک
    final lp = Paint()..color = const Color(0xFF1B5E20)..strokeWidth = 2;
    final spacing = size.width * 0.12;
    final off = (offset * 60) % spacing;
    for (double x = -spacing + off; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + 15, size.height * 0.18), lp);
    }
    // سنگ‌های تزئینی
    final sp = Paint()..color = const Color(0xFF4E342E);
    for (int i = 0; i < 10; i++) {
      final sx = (i * size.width * 0.12 - (offset * 80) % (size.width * 0.12));
      canvas.drawOval(Rect.fromLTWH(sx, size.height * 0.22, 18, 9), sp);
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.offset != old.offset;
}

// ============================================
// مدل‌ها
// ============================================
class _Obstacle {
  double x;
  final int type;
  _Obstacle({required this.x, required this.type});
}

class _Cloud {
  double x, y, scale;
  _Cloud({required this.x, required this.y, required this.scale});
}

class _Star {
  final double x, y, size;
  _Star({required this.x, required this.y, required this.size});
}
