import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// ============================================
// بازی Endless Runner
// ============================================
class GameRunnerScreen extends StatefulWidget {
  const GameRunnerScreen({super.key});
  @override
  State<GameRunnerScreen> createState() => _GameRunnerScreenState();
}

class _GameRunnerScreenState extends State<GameRunnerScreen>
    with TickerProviderStateMixin {
  // وضعیت بازی
  bool _isPlaying = false;
  bool _isDead = false;
  int _score = 0;
  int _lives = 3;
  double _speed = 1.0;

  // موقعیت کاراکتر
  double _girlY = 0.0; // 0 = زمین
  bool _isJumping = false;
  bool _isRunning = false;
  double _jumpVelocity = 0.0;
  static const double _gravity = 0.012;
  static const double _jumpForce = -0.038;
  static const double _groundY = 0.0;

  // موانع
  List<_Obstacle> _obstacles = [];
  double _obstacleTimer = 0;
  double _nextObstacleIn = 2.0;

  // انیمیشن‌ها
  late AnimationController _runController;
  late AnimationController _bgController;
  late AnimationController _deathController;
  late Animation<double> _deathAnim;

  // ابرها و پس‌زمینه
  List<_Cloud> _clouds = [];
  List<_Star> _stars = [];

  Timer? _gameTimer;
  Timer? _scoreTimer;

  @override
  void initState() {
    super.initState();
    _runController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _deathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _deathAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _deathController, curve: Curves.easeOut),
    );

    _initClouds();
    _initStars();
  }

  void _initClouds() {
    _clouds = List.generate(6, (i) => _Cloud(
      x: i * 0.2 + Random().nextDouble() * 0.1,
      y: 0.05 + Random().nextDouble() * 0.25,
      scale: 0.5 + Random().nextDouble() * 0.8,
    ));
  }

  void _initStars() {
    _stars = List.generate(20, (i) => _Star(
      x: Random().nextDouble(),
      y: Random().nextDouble() * 0.5,
      size: 1.0 + Random().nextDouble() * 2,
    ));
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isDead = false;
      _score = 0;
      _lives = 3;
      _speed = 1.0;
      _girlY = _groundY;
      _isJumping = false;
      _obstacles = [];
      _obstacleTimer = 0;
      _nextObstacleIn = 2.0;
    });

    _deathController.reset();

    // loop اصلی بازی
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);

    // امتیاز
    _scoreTimer?.cancel();
    _scoreTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isPlaying && !_isDead) {
        setState(() {
          _score++;
          // سرعت تدریجی زیاد میشه
          _speed = 1.0 + _score * 0.003;
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
        _girlY += _jumpVelocity;
        if (_girlY >= _groundY) {
          _girlY = _groundY;
          _isJumping = false;
          _jumpVelocity = 0;
        }
      }

      // حرکت ابرها
      for (final cloud in _clouds) {
        cloud.x -= 0.001 * _speed;
        if (cloud.x < -0.2) {
          cloud.x = 1.1;
          cloud.y = 0.05 + Random().nextDouble() * 0.25;
        }
      }

      // زمان‌بندی موانع
      _obstacleTimer += 0.016 * _speed;
      if (_obstacleTimer >= _nextObstacleIn) {
        _obstacleTimer = 0;
        _nextObstacleIn = 1.5 + Random().nextDouble() * 2.0;
        _obstacles.add(_Obstacle(
          x: 1.1,
          type: Random().nextInt(3),
        ));
      }

      // حرکت موانع
      for (final obs in _obstacles) {
        obs.x -= 0.008 * _speed;
      }
      _obstacles.removeWhere((o) => o.x < -0.15);

      // تشخیص برخورد
      for (final obs in _obstacles) {
        if (_checkCollision(obs)) {
          _lives--;
          _obstacles.remove(obs);
          if (_lives <= 0) {
            _gameOver();
          } else {
            // لرزش و invincible کوتاه
            _deathController.forward(from: 0).then((_) {
              _deathController.reverse();
            });
          }
          break;
        }
      }
    });
  }

  bool _checkCollision(_Obstacle obs) {
    // موقعیت دختر روی صفحه
    const girlLeft = 0.12;
    const girlRight = 0.22;
    final girlBottom = _groundY;
    final girlTop = _girlY - 0.18;

    final obsLeft = obs.x + 0.01;
    final obsRight = obs.x + 0.07;
    const obsBottom = 0.0;
    final obsTop = obs.type == 2 ? -0.15 : -0.12;

    return girlRight > obsLeft &&
        girlLeft < obsRight &&
        girlBottom > obsTop &&
        girlTop < obsBottom;
  }

  void _jump() {
    if (!_isPlaying) {
      _startGame();
      return;
    }
    if (!_isJumping && _girlY >= _groundY) {
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
    _deathController.forward();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _scoreTimer?.cancel();
    _runController.dispose();
    _bgController.dispose();
    _deathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final groundHeight = size.height * 0.72;

    return Scaffold(
      body: GestureDetector(
        onTap: _jump,
        child: Stack(
          children: [
            // پس‌زمینه گرادیان
            AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => CustomPaint(
                painter: _BackgroundPainter(_bgController.value, _clouds, _stars),
                child: const SizedBox.expand(),
              ),
            ),

            // زمین
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                painter: _GroundPainter(_bgController.value * _speed),
                size: Size(size.width, size.height * 0.28),
              ),
            ),

            // موانع
            ...(_obstacles.map((obs) => Positioned(
              left: obs.x * size.width,
              bottom: size.height * 0.28 - 8,
              child: _ObstacleWidget(type: obs.type),
            ))),

            // کاراکتر دختر
            AnimatedBuilder(
              animation: Listenable.merge([_runController, _deathAnim]),
              builder: (_, __) {
                final shake = _deathAnim.value * 8 * sin(_deathAnim.value * pi * 6);
                return Positioned(
                  left: size.width * 0.15 + shake,
                  bottom: groundHeight - 8 - (_girlY * -1 * size.height * 0.4),
                  child: _GirlCharacter(
                    isJumping: _isJumping,
                    runValue: _runController.value,
                    isDead: _isDead,
                  ),
                );
              },
            ),

            // HUD — امتیاز و جان
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // دکمه برگشت
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    // امتیاز
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'امتیاز: $_score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // جان‌ها
                    Row(
                      children: List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          i < _lives ? Icons.favorite : Icons.favorite_border,
                          color: i < _lives ? Colors.red : Colors.white30,
                          size: 22,
                        ),
                      )),
                    ),
                  ],
                ),
              ),
            ),

            // صفحه شروع
            if (!_isPlaying && !_isDead)
              _buildStartScreen(),

            // صفحه Game Over
            if (_isDead)
              _buildGameOverScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏃‍♀️', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text(
              'دختر دونده',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'برای شروع ضربه بزن!',
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white30),
              ),
              child: const Text(
                '💡 برای پریدن روی صفحه بزن',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.4),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💔', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'بازی تموم شد!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'امتیاز: $_score',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'دوباره بازی کن! 🏃‍♀️',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// کاراکتر دختر — pixel art با کد
// ============================================
class _GirlCharacter extends StatelessWidget {
  final bool isJumping;
  final double runValue;
  final bool isDead;

  const _GirlCharacter({
    required this.isJumping,
    required this.runValue,
    required this.isDead,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GirlPainter(
        isJumping: isJumping,
        runValue: runValue,
        isDead: isDead,
      ),
      size: const Size(52, 80),
    );
  }
}

class _GirlPainter extends CustomPainter {
  final bool isJumping;
  final double runValue;
  final bool isDead;

  _GirlPainter({
    required this.isJumping,
    required this.runValue,
    required this.isDead,
  });

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

    // پاها
    final legPaint = Paint()..color = const Color(0xFFE8A87C);
    final legOffset = isJumping ? 0.0 : sin(runValue * pi) * 8;

    // پای چپ
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.68 + legOffset, w * 0.18, h * 0.22),
        const Radius.circular(4),
      ),
      legPaint,
    );
    // پای راست
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.52, h * 0.68 - legOffset, w * 0.18, h * 0.22),
        const Radius.circular(4),
      ),
      legPaint,
    );

    // کفش‌ها
    final shoePaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.88 + legOffset, w * 0.22, h * 0.1),
        const Radius.circular(4),
      ),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.50, h * 0.88 - legOffset, w * 0.22, h * 0.1),
        const Radius.circular(4),
      ),
      shoePaint,
    );

    // دامن
    final skirtPaint = Paint()..color = const Color(0xFFE91E63);
    final skirtPath = Path();
    skirtPath.moveTo(w * 0.15, h * 0.55);
    skirtPath.lineTo(w * 0.08, h * 0.72);
    skirtPath.lineTo(w * 0.88, h * 0.72);
    skirtPath.lineTo(w * 0.82, h * 0.55);
    skirtPath.close();
    canvas.drawPath(skirtPath, skirtPaint);

    // بدن
    final bodyPaint = Paint()..color = const Color(0xFFFF80AB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.35, w * 0.55, h * 0.25),
        const Radius.circular(8),
      ),
      bodyPaint,
    );

    // دست‌ها
    final armPaint = Paint()..color = const Color(0xFFFFB74D);
    final armSwing = isJumping ? 0.0 : cos(runValue * pi) * 10;
    // دست چپ
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.35 + armSwing, w * 0.16, h * 0.22),
        const Radius.circular(6),
      ),
      armPaint,
    );
    // دست راست
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.77, h * 0.35 - armSwing, w * 0.16, h * 0.22),
        const Radius.circular(6),
      ),
      armPaint,
    );

    // گردن
    final skinPaint = Paint()..color = const Color(0xFFFFCC80);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.40, h * 0.22, w * 0.18, h * 0.15),
        const Radius.circular(4),
      ),
      skinPaint,
    );

    // صورت
    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.04, w * 0.55, h * 0.24),
      skinPaint,
    );

    // موهای بلوند فرفری
    final hairPaint = Paint()..color = const Color(0xFFFFD700);
    // موی بالا
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.0, w * 0.62, h * 0.16),
      hairPaint,
    );
    // موهای کنار فرفری
    for (int i = 0; i < 5; i++) {
      final cx = w * (0.08 + i * 0.08);
      final cy = h * (0.06 + (i % 2) * 0.04);
      canvas.drawCircle(Offset(cx, cy), w * 0.1, hairPaint);
    }
    // موهای پشت (بلند)
    final longHairPaint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.65, h * 0.08, w * 0.2, h * 0.35),
        const Radius.circular(10),
      ),
      longHairPaint,
    );
    // فرفری پایین مو
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(w * (0.68 + i * 0.06), h * 0.42),
        w * 0.09,
        longHairPaint,
      );
    }

    // چشم‌ها
    final eyePaint = Paint()..color = const Color(0xFF1A237E);
    canvas.drawCircle(Offset(w * 0.37, h * 0.13), w * 0.055, eyePaint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.13), w * 0.055, eyePaint);
    // سفیدی چشم
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.38, h * 0.12), w * 0.025, whitePaint);
    canvas.drawCircle(Offset(w * 0.61, h * 0.12), w * 0.025, whitePaint);

    // لبخند
    final smilePaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.36, h * 0.14, w * 0.26, h * 0.08),
      0,
      pi,
      false,
      smilePaint,
    );

    // ستاره روی لباس
    final starPaint = Paint()..color = Colors.white.withOpacity(0.6);
    canvas.drawCircle(Offset(w * 0.50, h * 0.46), w * 0.06, starPaint);

    if (isDead) canvas.restore();
  }

  @override
  bool shouldRepaint(_GirlPainter old) =>
      old.isJumping != isJumping ||
      old.runValue != runValue ||
      old.isDead != isDead;
}

// ============================================
// موانع
// ============================================
class _ObstacleWidget extends StatelessWidget {
  final int type;
  const _ObstacleWidget({required this.type});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ObstaclePainter(type: type),
      size: const Size(44, 60),
    );
  }
}

class _ObstaclePainter extends CustomPainter {
  final int type;
  _ObstaclePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    if (type == 0) {
      // سنگ
      final p = Paint()..color = const Color(0xFF78909C);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.7),
          const Radius.circular(8),
        ),
        p,
      );
      final p2 = Paint()..color = const Color(0xFF90A4AE);
      canvas.drawOval(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.15,
            size.width * 0.8, size.height * 0.35),
        p2,
      );
    } else if (type == 1) {
      // کاکتوس
      final p = Paint()..color = const Color(0xFF2E7D32);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.35, 0, size.width * 0.3, size.height),
          const Radius.circular(6),
        ),
        p,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height * 0.3, size.width * 0.4, size.height * 0.22),
          const Radius.circular(6),
        ),
        p,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.6, size.height * 0.4,
              size.width * 0.4, size.height * 0.22),
          const Radius.circular(6),
        ),
        p,
      );
    } else {
      // پرنده
      final p = Paint()..color = const Color(0xFF6A1B9A);
      canvas.drawOval(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.1,
            size.width * 0.7, size.height * 0.35),
        p,
      );
      // بال‌ها
      final wingPath = Path();
      wingPath.moveTo(size.width * 0.1, size.height * 0.2);
      wingPath.quadraticBezierTo(0, size.height * 0.0,
          size.width * 0.3, size.height * 0.15);
      canvas.drawPath(wingPath, p);
      final wingPath2 = Path();
      wingPath2.moveTo(size.width * 0.9, size.height * 0.2);
      wingPath2.quadraticBezierTo(size.width, size.height * 0.0,
          size.width * 0.7, size.height * 0.15);
      canvas.drawPath(wingPath2, p);
      // چشم
      canvas.drawCircle(
        Offset(size.width * 0.65, size.height * 0.22),
        size.width * 0.06,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(size.width * 0.65, size.height * 0.22),
        size.width * 0.03,
        Paint()..color = Colors.black,
      );
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
    // آسمان گرادیان
    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A237E),
        const Color(0xFF7B1FA2),
        const Color(0xFFE91E63),
        const Color(0xFFFF9800),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.72),
      Paint()..shader = grad.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height * 0.72)),
    );

    // ستاره‌ها
    for (final star in stars) {
      final opacity = 0.4 + 0.6 * sin((t + star.x) * 2 * pi);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height * 0.72),
        star.size,
        Paint()..color = Colors.white.withOpacity(opacity),
      );
    }

    // ابرها
    for (final cloud in clouds) {
      _drawCloud(canvas, size, cloud);
    }
  }

  void _drawCloud(Canvas canvas, Size size, _Cloud cloud) {
    final p = Paint()..color = Colors.white.withOpacity(0.15);
    final cx = cloud.x * size.width;
    final cy = cloud.y * size.height * 0.72;
    final r = 20.0 * cloud.scale;
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx + r * 0.8, cy - r * 0.2), r * 0.75, p);
    canvas.drawCircle(Offset(cx - r * 0.8, cy - r * 0.1), r * 0.65, p);
    canvas.drawCircle(Offset(cx + r * 1.5, cy + r * 0.1), r * 0.6, p);
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.15),
      Paint()..color = const Color(0xFF388E3C),
    );
    // خاک
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.15, size.width, size.height * 0.85),
      Paint()..color = const Color(0xFF795548),
    );

    // خطوط زمین متحرک
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2;
    final lineSpacing = size.width * 0.15;
    final off = (offset * size.width * 0.5) % lineSpacing;
    for (double x = -lineSpacing + off; x < size.width + lineSpacing; x += lineSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x - 30, size.height * 0.15), linePaint);
    }

    // سنگ‌های تزئینی
    final stonePaint = Paint()..color = const Color(0xFF5D4037);
    for (int i = 0; i < 8; i++) {
      final sx = (i * size.width * 0.14 - (offset * size.width * 0.3) % (size.width * 0.14));
      canvas.drawOval(
        Rect.fromLTWH(sx, size.height * 0.18, 20, 10),
        stonePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.offset != offset;
}

// ============================================
// مدل‌های کمکی
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
