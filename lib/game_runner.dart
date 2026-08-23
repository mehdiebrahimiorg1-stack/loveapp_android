import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// ============ ENUMS & CONSTANTS ============
enum BiomeType { night, dawn, day, dusk, storm }
enum ObstacleType { rockSmall, rockBig, cactus, deadTree, mushroom, log, bird, bat, eagle }

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

  // فیزیک
  double _girlJumpOffset = 0.0;
  bool _isJumping = false;
  double _jumpVelocity = 0.0;
  bool _jumpPressed = false;

  List<_Obstacle> _obstacles = [];
  double _obstacleTimer = 0;
  double _nextObstacleIn = 2.0;

  late AnimationController _runController;
  late AnimationController _bgController;
  late AnimationController _hitController;
  late AnimationController _hairController;

  List<_Cloud> _clouds = [];
  List<_Star> _stars = [];
  List<_Tree> _bgTrees = [];

  Timer? _gameTimer;
  Timer? _scoreTimer;

  BiomeType _biome = BiomeType.night;
  double _biomeTimer = 0;
  double _nextBiomeIn = 18.0;
  double _biomeTransition = 1.0; // 0=transitioning, 1=settled

  static const double _gravity = 1.4;
  static const double _jumpForce = -24.0;

  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _runController = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))..repeat(reverse: true);
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _hitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _hairController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _initWorld();
  }

  void _initWorld() {
    _clouds = List.generate(7, (i) => _Cloud(
      x: i * 0.15 + _rng.nextDouble() * 0.06,
      y: 0.04 + _rng.nextDouble() * 0.2,
      scale: 0.5 + _rng.nextDouble() * 0.9,
      speed: 0.0004 + _rng.nextDouble() * 0.0004,
    ));
    _stars = List.generate(35, (i) => _Star(
      x: _rng.nextDouble(), y: _rng.nextDouble() * 0.5,
      size: 0.8 + _rng.nextDouble() * 2.2,
      twinklePhase: _rng.nextDouble(),
    ));
    _bgTrees = List.generate(8, (i) => _Tree(
      x: i * 0.14 + _rng.nextDouble() * 0.05,
      scale: 0.5 + _rng.nextDouble() * 0.7,
      type: _rng.nextInt(4),
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
      _jumpPressed = false;
      _obstacles = [];
      _obstacleTimer = 0;
      _nextObstacleIn = 2.0;
      _biome = BiomeType.night;
      _biomeTimer = 0;
      _nextBiomeIn = 18.0;
      _biomeTransition = 1.0;
    });
    _hitController.reset();
    _initWorld();

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
    _scoreTimer?.cancel();
    _scoreTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isPlaying && !_isDead && mounted) {
        setState(() {
          _score++;
          // سرعت خیلی آروم زیاد میشه
          _speed = 1.0 + _score * 0.002;
        });
      }
    });
  }

  void _gameLoop(Timer timer) {
    if (!_isPlaying || _isDead || !mounted) return;
    setState(() {
      // پریدن بلافاصله وقتی انگشت روی صفحه‌ست
      if (_jumpPressed && !_isJumping && _girlJumpOffset <= 0) {
        _isJumping = true;
        _jumpVelocity = _jumpForce;
      }

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
        c.x -= c.speed * _speed;
        if (c.x < -0.3) {
          c.x = 1.1 + _rng.nextDouble() * 0.15;
          c.y = 0.04 + _rng.nextDouble() * 0.2;
          c.scale = 0.5 + _rng.nextDouble() * 0.9;
        }
      }

      // درخت‌های پس‌زمینه
      for (final t in _bgTrees) {
        t.x -= 0.0015 * _speed;
        if (t.x < -0.15) {
          t.x = 1.05 + _rng.nextDouble() * 0.1;
          t.scale = 0.5 + _rng.nextDouble() * 0.7;
          t.type = _rng.nextInt(4);
        }
      }

      // biome تغییر
      _biomeTimer += 0.016 * _speed;
      if (_biomeTimer >= _nextBiomeIn) {
        _biomeTimer = 0;
        _nextBiomeIn = 15.0 + _rng.nextDouble() * 12.0;
        final biomes = BiomeType.values.where((b) => b != _biome).toList();
        _biome = biomes[_rng.nextInt(biomes.length)];
        _biomeTransition = 0.0;
      }
      if (_biomeTransition < 1.0) _biomeTransition = (_biomeTransition + 0.008).clamp(0.0, 1.0);

      // موانع
      _obstacleTimer += 0.016 * _speed;
      if (_obstacleTimer >= _nextObstacleIn) {
        _obstacleTimer = 0;
        _nextObstacleIn = 1.2 + _rng.nextDouble() * 1.6;
        _spawnObstacle();
      }

      for (final o in _obstacles) {
        o.x -= 0.007 * _speed;
      }
      _obstacles.removeWhere((o) => o.x < -0.18);

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

  void _spawnObstacle() {
    // بسته به بایوم، موانع مختلف
    List<ObstacleType> groundObs = [ObstacleType.rockSmall, ObstacleType.rockBig, ObstacleType.log];
    List<ObstacleType> airObs = [ObstacleType.bird, ObstacleType.bat, ObstacleType.eagle];

    switch (_biome) {
      case BiomeType.night:
        groundObs = [ObstacleType.rockSmall, ObstacleType.rockBig, ObstacleType.log];
        airObs = [ObstacleType.bat];
        break;
      case BiomeType.dawn:
      case BiomeType.dusk:
        groundObs = [ObstacleType.cactus, ObstacleType.deadTree, ObstacleType.rockSmall];
        airObs = [ObstacleType.bird, ObstacleType.eagle];
        break;
      case BiomeType.day:
        groundObs = [ObstacleType.mushroom, ObstacleType.log, ObstacleType.cactus, ObstacleType.rockBig];
        airObs = [ObstacleType.bird, ObstacleType.eagle];
        break;
      case BiomeType.storm:
        groundObs = [ObstacleType.rockBig, ObstacleType.deadTree, ObstacleType.log];
        airObs = [ObstacleType.bat, ObstacleType.eagle];
        break;
    }

    // گاهی دوتا مانع پشت هم
    bool isAir = _rng.nextDouble() < 0.3;
    final type = isAir
        ? airObs[_rng.nextInt(airObs.length)]
        : groundObs[_rng.nextInt(groundObs.length)];

    _obstacles.add(_Obstacle(x: 1.06, type: type));

    // گاهی گروه
    if (_speed > 1.5 && _rng.nextDouble() < 0.25 && !isAir) {
      final type2 = groundObs[_rng.nextInt(groundObs.length)];
      _obstacles.add(_Obstacle(x: 1.18, type: type2));
    }
  }

  bool _checkCollision(_Obstacle obs) {
    const girlLeft = 0.11;
    const girlRight = 0.21;
    final obsLeft = obs.x + 0.012;
    final obsRight = obs.x + 0.075;

    if (girlRight <= obsLeft || girlLeft >= obsRight) return false;

    final isAir = obs.type == ObstacleType.bird || obs.type == ObstacleType.bat || obs.type == ObstacleType.eagle;
    if (isAir) {
      // پرنده در ارتفاع بالاست — فقط اگه پریده باشه برخورد داره
      if (_girlJumpOffset < 40) return false; // زیر پرنده
      if (_girlJumpOffset > 120) return false; // خیلی بالاتر
      return true;
    } else {
      return _girlJumpOffset < 50;
    }
  }

  void _jump() {
    if (!_isPlaying) { _startGame(); return; }
  }

  void _onPointerDown() {
    _jumpPressed = true;
    if (!_isPlaying) { _startGame(); return; }
    if (!_isJumping && _girlJumpOffset <= 0 && _isPlaying && !_isDead) {
      setState(() {
        _isJumping = true;
        _jumpVelocity = _jumpForce;
      });
    }
  }

  void _onPointerUp() {
    _jumpPressed = false;
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
    _hairController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final groundFromBottom = size.height * 0.24;
    final girlBottom = groundFromBottom + _girlJumpOffset;

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _onPointerDown(),
        onPointerUp: (_) => _onPointerUp(),
        child: Stack(
          children: [
            // پس‌زمینه
            AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) => CustomPaint(
                painter: _BackgroundPainter(_bgController.value, _clouds, _stars, _bgTrees, _biome, _biomeTransition),
                size: size,
              ),
            ),

            // زمین
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (_, __) => CustomPaint(
                  painter: _GroundPainter(_bgController.value * _speed * 1.8, _biome),
                  size: Size(size.width, groundFromBottom),
                ),
              ),
            ),

            // موانع
            ...(_obstacles.map((obs) {
              double obsH = _obstacleHeight(obs.type);
              double obsBottom = groundFromBottom - 4;
              if (obs.type == ObstacleType.bird || obs.type == ObstacleType.bat || obs.type == ObstacleType.eagle) {
                obsBottom = groundFromBottom + 65 + _rng.nextDouble() * 0; // ثابت در ارتفاع
              }
              return Positioned(
                left: obs.x * size.width,
                bottom: obsBottom,
                child: _ObstacleWidget(type: obs.type, h: obsH),
              );
            })),

            // کاراکتر
            AnimatedBuilder(
              animation: Listenable.merge([_runController, _hitController, _hairController]),
              builder: (_, __) {
                final shake = _hitController.value > 0 ? sin(_hitController.value * pi * 8) * 7 : 0.0;
                final opacity = _hitController.value > 0 ? (sin(_hitController.value * pi * 6) > 0 ? 1.0 : 0.25) : 1.0;
                return Positioned(
                  left: size.width * 0.10 + shake,
                  bottom: girlBottom,
                  child: Opacity(
                    opacity: opacity,
                    child: _GirlCharacter(
                      isJumping: _isJumping,
                      runValue: _runController.value,
                      hairValue: _hairController.value,
                      isDead: _isDead,
                      speed: _speed,
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
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                      child: Text('امتیاز: $_score',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      children: List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(i < _lives ? Icons.favorite : Icons.favorite_border,
                            color: i < _lives ? Colors.red : Colors.white30, size: 24),
                      )),
                    ),
                  ],
                ),
              ),
            ),

            // بایوم نشانگر
            if (_isPlaying && !_isDead)
              Positioned(
                top: 60, left: 0, right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _biomeTransition < 0.3 ? (1.0 - _biomeTransition * 3).clamp(0, 1) : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                      child: Text(_biomeName(_biome),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ),
                ),
              ),

            if (!_isPlaying && !_isDead) _buildStartScreen(),
            if (_isDead) _buildGameOverScreen(),
          ],
        ),
      ),
    );
  }

  double _obstacleHeight(ObstacleType t) {
    switch (t) {
      case ObstacleType.rockSmall: return 42;
      case ObstacleType.rockBig: return 62;
      case ObstacleType.cactus: return 72;
      case ObstacleType.deadTree: return 80;
      case ObstacleType.mushroom: return 48;
      case ObstacleType.log: return 38;
      case ObstacleType.bird: return 38;
      case ObstacleType.bat: return 32;
      case ObstacleType.eagle: return 44;
    }
  }

  String _biomeName(BiomeType b) {
    switch (b) {
      case BiomeType.night: return '🌙 شب';
      case BiomeType.dawn: return '🌅 سپیده‌دم';
      case BiomeType.day: return '☀️ روز';
      case BiomeType.dusk: return '🌇 غروب';
      case BiomeType.storm: return '⛈️ طوفان';
    }
  }

  Widget _buildStartScreen() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏃‍♀️', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            const Text('دختر دونده',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white,
                    shadows: [Shadow(color: Colors.purple, blurRadius: 16)])),
            const SizedBox(height: 10),
            Text('برای شروع ضربه بزن!',
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.85))),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text('💡 نگه داشتن انگشت = پرش بلندتر',
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
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.pink)),
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
// کاراکتر دختر — گرافیک کامل
// ============================================
class _GirlCharacter extends StatelessWidget {
  final bool isJumping, isDead;
  final double runValue, hairValue, speed;
  const _GirlCharacter({required this.isJumping, required this.runValue, required this.hairValue, required this.isDead, required this.speed});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GirlPainter(isJumping: isJumping, runValue: runValue, hairValue: hairValue, isDead: isDead, speed: speed),
    size: const Size(60, 90),
  );
}

class _GirlPainter extends CustomPainter {
  final bool isJumping, isDead;
  final double runValue, hairValue, speed;
  _GirlPainter({required this.isJumping, required this.runValue, required this.hairValue, required this.isDead, required this.speed});

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

    final leg = isJumping ? 0.0 : sin(runValue * pi) * 10.0;
    final armSwing = isJumping ? -12.0 : cos(runValue * pi) * 10.0;

    // ===== سایه =====
    canvas.drawOval(
      Rect.fromLTWH(w * 0.08, h * 0.95, w * 0.84, h * 0.05),
      Paint()..color = Colors.black.withOpacity(0.2),
    );

    // ===== پاها با جزئیات =====
    // ساق چپ
    final legPaint = Paint()..color = const Color(0xFFFFCC80);
    _drawRoundedLeg(canvas, Rect.fromLTWH(w * 0.22, h * 0.63 + leg, w * 0.17, h * 0.19), legPaint);
    // ساق راست
    _drawRoundedLeg(canvas, Rect.fromLTWH(w * 0.58, h * 0.63 - leg, w * 0.17, h * 0.19), legPaint);

    // جوراب‌های خطدار
    _drawStriped(canvas, Rect.fromLTWH(w * 0.23, h * 0.77 + leg, w * 0.15, h * 0.09),
        const Color(0xFFFFFFFF), const Color(0xFFE91E63));
    _drawStriped(canvas, Rect.fromLTWH(w * 0.59, h * 0.77 - leg, w * 0.15, h * 0.09),
        const Color(0xFFFFFFFF), const Color(0xFFE91E63));

    // کفش‌های جزئیات‌دار
    _drawShoe(canvas, Rect.fromLTWH(w * 0.18, h * 0.84 + leg, w * 0.26, h * 0.12));
    _drawShoe(canvas, Rect.fromLTWH(w * 0.54, h * 0.84 - leg, w * 0.26, h * 0.12));

    // ===== دامن با چین و چروک =====
    final skirtPaint = Paint()..color = const Color(0xFFE91E63);
    final skirtPath = Path()
      ..moveTo(w * 0.20, h * 0.52)
      ..cubicTo(w * 0.10, h * 0.60, w * 0.05, h * 0.68, w * 0.10, h * 0.72)
      ..quadraticBezierTo(w * 0.50, h * 0.78, w * 0.90, h * 0.72)
      ..cubicTo(w * 0.95, h * 0.68, w * 0.90, h * 0.60, w * 0.80, h * 0.52)
      ..close();
    canvas.drawPath(skirtPath, skirtPaint);
    // چین‌های دامن
    final foldPaint = Paint()
      ..color = const Color(0xFFC2185B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (int i = 0; i < 5; i++) {
      final fold = Path()
        ..moveTo(w * (0.22 + i * 0.14), h * 0.53)
        ..quadraticBezierTo(w * (0.18 + i * 0.14), h * 0.68, w * (0.22 + i * 0.14), h * 0.75);
      canvas.drawPath(fold, foldPaint);
    }
    // لبه دامن تزئینی
    canvas.drawPath(skirtPath, Paint()
      ..color = const Color(0xFFF48FB1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);

    // ===== بدن (بلوز) =====
    final bodyPaint = Paint()..color = const Color(0xFFFF80AB);
    final bodyPath = Path()
      ..moveTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.22, h * 0.34)
      ..quadraticBezierTo(w * 0.50, h * 0.30, w * 0.78, h * 0.34)
      ..lineTo(w * 0.78, h * 0.52)
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);
    // خط وسط بلوز
    canvas.drawLine(Offset(w * 0.50, h * 0.33), Offset(w * 0.50, h * 0.52),
        Paint()..color = const Color(0xFFC2185B).withOpacity(0.5)..strokeWidth = 1.5);
    // دکمه‌ها
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(w * 0.50, h * (0.37 + i * 0.05)), w * 0.04,
          Paint()..color = Colors.white.withOpacity(0.9));
      canvas.drawCircle(Offset(w * 0.50, h * (0.37 + i * 0.05)), w * 0.025,
          Paint()..color = const Color(0xFFE91E63).withOpacity(0.7));
    }

    // ===== کمربند =====
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.20, h * 0.50, w * 0.60, h * 0.045), const Radius.circular(4)),
      Paint()..color = const Color(0xFF880E4F),
    );
    // سگک
    canvas.drawRect(Rect.fromLTWH(w * 0.44, h * 0.50, w * 0.12, h * 0.045),
        Paint()..color = const Color(0xFFFFD700));

    // ===== دست‌ها با آرنج =====
    final skinPaint = Paint()..color = const Color(0xFFFFB74D);
    // بازوی چپ
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.33 + armSwing * 0.5, w * 0.16, h * 0.15), const Radius.circular(7)),
      skinPaint,
    );
    // ساعد چپ
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.04, h * 0.44 + armSwing, w * 0.14, h * 0.14), const Radius.circular(6)),
      skinPaint,
    );
    // مشت چپ
    _drawFist(canvas, Offset(w * 0.09, h * 0.57 + armSwing), w * 0.10);

    // بازوی راست
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.79, h * 0.33 - armSwing * 0.5, w * 0.16, h * 0.15), const Radius.circular(7)),
      skinPaint,
    );
    // ساعد راست
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.82, h * 0.44 - armSwing, w * 0.14, h * 0.14), const Radius.circular(6)),
      skinPaint,
    );
    // مشت راست
    _drawFist(canvas, Offset(w * 0.91, h * 0.57 - armSwing), w * 0.10);

    // ===== گردن =====
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.40, h * 0.20, w * 0.20, h * 0.16), const Radius.circular(5)),
      Paint()..color = const Color(0xFFFFCC80),
    );

    // ===== موهای پشت (قبل از صورت) =====
    final hairPaint = Paint()..color = const Color(0xFFFFD700);
    final hairDark = Paint()..color = const Color(0xFFFFB300);

    // دنبالچه پشت (در حال حرکت)
    final ponytailSwing = sin(hairValue * pi) * 8.0;
    final ponytailPath = Path()
      ..moveTo(w * 0.72, h * 0.08)
      ..cubicTo(w * 0.90, h * 0.12 + ponytailSwing, w * 0.95, h * 0.28 + ponytailSwing, w * 0.85, h * 0.38 + ponytailSwing * 0.5);
    canvas.drawPath(ponytailPath, Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round);
    // رگه‌های موی دنبالچه
    canvas.drawPath(ponytailPath, Paint()
      ..color = const Color(0xFFFFF9C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);

    // ===== صورت =====
    // پایه صورت
    canvas.drawOval(Rect.fromLTWH(w * 0.18, h * 0.02, w * 0.64, h * 0.26), Paint()..color = const Color(0xFFFFCC80));

    // سایه جانبی صورت (حجم)
    canvas.drawOval(Rect.fromLTWH(w * 0.18, h * 0.08, w * 0.12, h * 0.16),
        Paint()..color = const Color(0xFFFFB74D).withOpacity(0.5));

    // گوش‌ها
    canvas.drawOval(Rect.fromLTWH(w * 0.14, h * 0.10, w * 0.10, h * 0.14), Paint()..color = const Color(0xFFFFCC80));
    canvas.drawOval(Rect.fromLTWH(w * 0.76, h * 0.10, w * 0.10, h * 0.14), Paint()..color = const Color(0xFFFFCC80));
    // داخل گوش
    canvas.drawOval(Rect.fromLTWH(w * 0.16, h * 0.12, w * 0.06, h * 0.09), Paint()..color = const Color(0xFFFFB74D).withOpacity(0.6));

    // ===== موهای روی سر =====
    // توده اصلی موها
    canvas.drawOval(Rect.fromLTWH(w * 0.14, h * -0.02, w * 0.72, h * 0.18), hairPaint);
    // فرهای روی سر
    for (int i = 0; i < 7; i++) {
      canvas.drawCircle(
        Offset(w * (0.13 + i * 0.12), h * (0.00 + sin(i * 1.3) * 0.03)),
        w * (0.09 + sin(i * 0.7) * 0.02),
        hairPaint,
      );
    }
    // رگه‌های مو
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(w * (0.25 + i * 0.10), h * -0.01),
        Offset(w * (0.22 + i * 0.10), h * 0.10),
        Paint()..color = const Color(0xFFFFF9C4).withOpacity(0.6)..strokeWidth = 1.5,
      );
    }
    // موهای کنار صورت
    canvas.drawOval(Rect.fromLTWH(w * 0.11, h * 0.05, w * 0.12, h * 0.18), hairDark);
    canvas.drawOval(Rect.fromLTWH(w * 0.77, h * 0.05, w * 0.12, h * 0.18), hairDark);

    // ===== ابروها =====
    final browPaint = Paint()..color = const Color(0xFFFFB300)..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.30, h * 0.09), Offset(w * 0.42, h * 0.07), browPaint);
    canvas.drawLine(Offset(w * 0.58, h * 0.07), Offset(w * 0.70, h * 0.09), browPaint);

    // ===== چشم‌ها =====
    // سایه چشم
    canvas.drawOval(Rect.fromLTWH(w * 0.28, h * 0.10, w * 0.16, h * 0.10),
        Paint()..color = const Color(0xFF7B1FA2).withOpacity(0.25));
    canvas.drawOval(Rect.fromLTWH(w * 0.56, h * 0.10, w * 0.16, h * 0.10),
        Paint()..color = const Color(0xFF7B1FA2).withOpacity(0.25));

    // سفیدی
    canvas.drawOval(Rect.fromLTWH(w * 0.29, h * 0.10, w * 0.15, h * 0.10), Paint()..color = Colors.white);
    canvas.drawOval(Rect.fromLTWH(w * 0.56, h * 0.10, w * 0.15, h * 0.10), Paint()..color = Colors.white);

    // مردمک
    canvas.drawCircle(Offset(w * 0.37, h * 0.145), w * 0.048, Paint()..color = const Color(0xFF1A237E));
    canvas.drawCircle(Offset(w * 0.63, h * 0.145), w * 0.048, Paint()..color = const Color(0xFF1A237E));
    // درخشش
    canvas.drawCircle(Offset(w * 0.36, h * 0.135), w * 0.022, Paint()..color = Colors.white.withOpacity(0.9));
    canvas.drawCircle(Offset(w * 0.62, h * 0.135), w * 0.022, Paint()..color = Colors.white.withOpacity(0.9));
    // مردمک مشکی
    canvas.drawCircle(Offset(w * 0.37, h * 0.148), w * 0.028, Paint()..color = Colors.black87);
    canvas.drawCircle(Offset(w * 0.63, h * 0.148), w * 0.028, Paint()..color = Colors.black87);
    // نقطه درخشش
    canvas.drawCircle(Offset(w * 0.36, h * 0.138), w * 0.010, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.62, h * 0.138), w * 0.010, Paint()..color = Colors.white);

    // مژه‌های بالا
    final lash = Paint()..color = Colors.black..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(w * (0.30 + i * 0.035), h * 0.10),
        Offset(w * (0.285 + i * 0.035), h * 0.065),
        lash,
      );
      canvas.drawLine(
        Offset(w * (0.57 + i * 0.035), h * 0.10),
        Offset(w * (0.555 + i * 0.035), h * 0.065),
        lash,
      );
    }

    // گونه‌های صورتی گرادیانی
    final blushPaint = Paint()..color = Colors.pink.withOpacity(0.38);
    canvas.drawCircle(Offset(w * 0.27, h * 0.19), w * 0.09, blushPaint);
    canvas.drawCircle(Offset(w * 0.73, h * 0.19), w * 0.09, blushPaint);

    // بینی کوچک
    canvas.drawOval(Rect.fromLTWH(w * 0.46, h * 0.16, w * 0.08, h * 0.05),
        Paint()..color = const Color(0xFFFFB74D).withOpacity(0.7));

    // لبخند با دندون
    canvas.drawArc(Rect.fromLTWH(w * 0.36, h * 0.18, w * 0.28, h * 0.08), 0, pi, false,
        Paint()..color = const Color(0xFFE57373)..style = PaintingStyle.stroke..strokeWidth = 2.0);
    // دندون
    canvas.drawRect(Rect.fromLTWH(w * 0.38, h * 0.18, w * 0.24, h * 0.025),
        Paint()..color = Colors.white.withOpacity(0.85));

    if (isDead) canvas.restore();
  }

  void _drawRoundedLeg(Canvas canvas, Rect rect, Paint paint) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
    // خط روشن روی ساق
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 2, rect.top + 2, rect.width * 0.35, rect.height - 4), const Radius.circular(4)),
      Paint()..color = Colors.white.withOpacity(0.18),
    );
  }

  void _drawStriped(Canvas canvas, Rect rect, Color c1, Color c2) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = c1);
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top + i * rect.height / 3, rect.width, rect.height / 6),
          Paint()..color = c2.withOpacity(0.6));
    }
  }

  void _drawShoe(Canvas canvas, Rect rect) {
    // بدنه کفش
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = const Color(0xFF4E342E));
    // نوک کفش
    canvas.drawOval(Rect.fromLTWH(rect.right - rect.width * 0.35, rect.top + 1, rect.width * 0.38, rect.height - 2),
        Paint()..color = const Color(0xFF3E2723));
    // بند کفش
    canvas.drawLine(Offset(rect.left + 4, rect.top + rect.height * 0.4), Offset(rect.right - 6, rect.top + rect.height * 0.4),
        Paint()..color = Colors.white.withOpacity(0.5)..strokeWidth = 1.2);
    // درخشش
    canvas.drawOval(Rect.fromLTWH(rect.left + 3, rect.top + 2, rect.width * 0.3, rect.height * 0.3),
        Paint()..color = Colors.white.withOpacity(0.15));
  }

  void _drawFist(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFFFFB74D));
    // انگشتان
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(center.dx - r * 0.4 + i * r * 0.4, center.dy - r * 0.7),
        Offset(center.dx - r * 0.4 + i * r * 0.4, center.dy - r * 1.1),
        Paint()..color = const Color(0xFFFFCC80)..strokeWidth = 3..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GirlPainter old) =>
      old.isJumping != isJumping || old.runValue != runValue || old.hairValue != hairValue || old.isDead != isDead;
}

// ============================================
// موانع گوناگون
// ============================================
class _ObstacleWidget extends StatelessWidget {
  final ObstacleType type;
  final double h;
  const _ObstacleWidget({required this.type, required this.h});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ObstaclePainter(type: type),
    size: Size(52, h),
  );
}

class _ObstaclePainter extends CustomPainter {
  final ObstacleType type;
  _ObstaclePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (type) {
      case ObstacleType.rockSmall: _drawRock(canvas, w, h, false); break;
      case ObstacleType.rockBig: _drawRock(canvas, w, h, true); break;
      case ObstacleType.cactus: _drawCactus(canvas, w, h); break;
      case ObstacleType.deadTree: _drawDeadTree(canvas, w, h); break;
      case ObstacleType.mushroom: _drawMushroom(canvas, w, h); break;
      case ObstacleType.log: _drawLog(canvas, w, h); break;
      case ObstacleType.bird: _drawBird(canvas, w, h); break;
      case ObstacleType.bat: _drawBat(canvas, w, h); break;
      case ObstacleType.eagle: _drawEagle(canvas, w, h); break;
    }
  }

  void _drawRock(Canvas canvas, double w, double h, bool big) {
    final base = Paint()..color = const Color(0xFF78909C);
    final dark = Paint()..color = const Color(0xFF546E7A);
    final light = Paint()..color = const Color(0xFFB0BEC5);
    final rPath = Path()
      ..moveTo(w * 0.10, h)
      ..lineTo(w * 0.0, h * 0.55)
      ..quadraticBezierTo(w * 0.15, h * (big ? 0.05 : 0.18), w * 0.50, h * (big ? 0.00 : 0.12))
      ..quadraticBezierTo(w * 0.85, h * (big ? 0.05 : 0.18), w, h * 0.55)
      ..lineTo(w * 0.90, h)
      ..close();
    canvas.drawPath(rPath, base);
    // جزئیات
    canvas.drawPath(rPath, dark..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawLine(Offset(w * 0.3, h * 0.4), Offset(w * 0.5, h * 0.7), dark..strokeWidth = 1.8..style = PaintingStyle.stroke);
    canvas.drawLine(Offset(w * 0.6, h * 0.3), Offset(w * 0.75, h * 0.6), dark..strokeWidth = 1.2);
    // درخشش
    canvas.drawOval(Rect.fromLTWH(w * 0.15, h * 0.12, w * 0.3, h * 0.18), light..style = PaintingStyle.fill..color = Colors.white.withOpacity(0.22));
    // خزه
    canvas.drawOval(Rect.fromLTWH(w * 0.55, h * 0.08, w * 0.3, h * 0.12),
        Paint()..color = const Color(0xFF388E3C).withOpacity(0.5));
  }

  void _drawCactus(Canvas canvas, double w, double h) {
    final body = Paint()..color = const Color(0xFF388E3C);
    final dark = Paint()..color = const Color(0xFF1B5E20);
    final spine = Paint()..color = const Color(0xFFF5F5F5)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    // تنه
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.35, 0, w * 0.30, h), const Radius.circular(8)), body);
    // بازوی چپ
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.25, w * 0.40, h * 0.22), const Radius.circular(6)), body);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.05, w * 0.18, h * 0.24), const Radius.circular(6)), body);
    // بازوی راست
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.60, h * 0.35, w * 0.40, h * 0.22), const Radius.circular(6)), body);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.82, h * 0.15, w * 0.18, h * 0.24), const Radius.circular(6)), body);

    // خط عمودی
    canvas.drawLine(Offset(w * 0.50, 2), Offset(w * 0.50, h), dark..strokeWidth = 2..style = PaintingStyle.stroke);
    // خارها
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(Offset(w * 0.35, h * (0.08 + i * 0.18)), Offset(w * 0.20, h * (0.06 + i * 0.18)), spine);
      canvas.drawLine(Offset(w * 0.65, h * (0.08 + i * 0.18)), Offset(w * 0.80, h * (0.06 + i * 0.18)), spine);
    }
    // گل
    canvas.drawCircle(Offset(w * 0.50, 0), w * 0.18, Paint()..color = const Color(0xFFFF4081));
    canvas.drawCircle(Offset(w * 0.50, 0), w * 0.08, Paint()..color = const Color(0xFFFFFF00));
  }

  void _drawDeadTree(Canvas canvas, double w, double h) {
    final trunk = Paint()..color = const Color(0xFF5D4037);
    final dark = Paint()..color = const Color(0xFF3E2723);

    // تنه اصلی
    final trunkPath = Path()
      ..moveTo(w * 0.38, h)
      ..lineTo(w * 0.30, h * 0.4)
      ..lineTo(w * 0.45, h * 0.05)
      ..lineTo(w * 0.55, h * 0.05)
      ..lineTo(w * 0.70, h * 0.4)
      ..lineTo(w * 0.62, h)
      ..close();
    canvas.drawPath(trunkPath, trunk);

    // شاخه‌های کج
    final branches = [
      [0.45, 0.15, 0.05, 0.10], [0.45, 0.15, 0.10, 0.28],
      [0.55, 0.15, 0.95, 0.10], [0.55, 0.15, 0.90, 0.28],
      [0.42, 0.30, 0.10, 0.22], [0.58, 0.30, 0.90, 0.22],
    ];
    for (final b in branches) {
      canvas.drawLine(Offset(w * b[0], h * b[1]), Offset(w * b[2], h * b[3]),
          trunk..strokeWidth = 3.5..style = PaintingStyle.stroke);
    }
    // بافت تنه
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(Offset(w * 0.42, h * (0.5 + i * 0.12)), Offset(w * 0.58, h * (0.48 + i * 0.12)),
          dark..strokeWidth = 1..style = PaintingStyle.stroke);
    }
  }

  void _drawMushroom(Canvas canvas, double w, double h) {
    // ساقه
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.28, h * 0.5, w * 0.44, h * 0.5), const Radius.circular(5)),
      Paint()..color = const Color(0xFFF5F5F5),
    );
    // خطوط ساقه
    canvas.drawLine(Offset(w * 0.35, h * 0.55), Offset(w * 0.35, h * 0.95), Paint()..color = Colors.grey.shade300..strokeWidth = 1.2);
    canvas.drawLine(Offset(w * 0.65, h * 0.55), Offset(w * 0.65, h * 0.95), Paint()..color = Colors.grey.shade300..strokeWidth = 1.2);
    // کلاهک
    final capPath = Path()
      ..moveTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.10, h * -0.05, w * 0.50, h * -0.02)
      ..quadraticBezierTo(w * 0.90, h * -0.05, w, h * 0.55)
      ..close();
    canvas.drawPath(capPath, Paint()..color = const Color(0xFFE53935));
    // خال‌های کلاهک
    canvas.drawCircle(Offset(w * 0.30, h * 0.22), w * 0.10, Paint()..color = Colors.white.withOpacity(0.9));
    canvas.drawCircle(Offset(w * 0.65, h * 0.18), w * 0.08, Paint()..color = Colors.white.withOpacity(0.9));
    canvas.drawCircle(Offset(w * 0.50, h * 0.38), w * 0.06, Paint()..color = Colors.white.withOpacity(0.9));
    canvas.drawCircle(Offset(w * 0.15, h * 0.40), w * 0.06, Paint()..color = Colors.white.withOpacity(0.9));
    // لبه کلاهک
    canvas.drawPath(capPath, Paint()..color = const Color(0xFFB71C1C)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawLog(Canvas canvas, double w, double h) {
    // بدنه اصلی
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, h * 0.2, w, h * 0.65), const Radius.circular(10)),
      Paint()..color = const Color(0xFF6D4C41),
    );
    // دو انتها
    canvas.drawOval(Rect.fromLTWH(-2, h * 0.18, w * 0.22, h * 0.7), Paint()..color = const Color(0xFF8D6E63));
    canvas.drawOval(Rect.fromLTWH(w * 0.80, h * 0.18, w * 0.22, h * 0.7), Paint()..color = const Color(0xFF8D6E63));
    // حلقه‌های چوب
    canvas.drawOval(Rect.fromLTWH(w * 0.02, h * 0.26, w * 0.16, h * 0.54), Paint()..color = const Color(0xFFA1887F)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawOval(Rect.fromLTWH(w * 0.05, h * 0.32, w * 0.10, h * 0.42), Paint()..color = const Color(0xFFA1887F)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // الگوی بدنه
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(Offset(w * (0.18 + i * 0.20), h * 0.22), Offset(w * (0.18 + i * 0.20), h * 0.82),
          Paint()..color = const Color(0xFF5D4037)..strokeWidth = 1.5);
    }
    // خزه روی چوب
    for (int i = 0; i < 5; i++) {
      canvas.drawOval(Rect.fromLTWH(w * (0.1 + i * 0.16), h * 0.20, w * 0.10, h * 0.08),
          Paint()..color = const Color(0xFF4CAF50).withOpacity(0.7));
    }
  }

  void _drawBird(Canvas canvas, double w, double h) {
    final body = Paint()..color = const Color(0xFF1565C0);
    // بدن
    canvas.drawOval(Rect.fromLTWH(w * 0.15, h * 0.2, w * 0.70, h * 0.55), body);
    // سر
    canvas.drawCircle(Offset(w * 0.78, h * 0.25), w * 0.20, Paint()..color = const Color(0xFF1565C0));
    // بال‌ها باز
    final wingL = Path()
      ..moveTo(w * 0.15, h * 0.40)
      ..quadraticBezierTo(-w * 0.05, -h * 0.10, w * 0.25, h * 0.25);
    canvas.drawPath(wingL, Paint()..color = const Color(0xFF1976D2)..style = PaintingStyle.fill);
    final wingR = Path()
      ..moveTo(w * 0.85, h * 0.40)
      ..quadraticBezierTo(w * 1.05, -h * 0.10, w * 0.75, h * 0.25);
    canvas.drawPath(wingR, Paint()..color = const Color(0xFF1976D2));
    // نوار بال
    final wingLStroke = Path()..moveTo(w * 0.15, h * 0.40)..quadraticBezierTo(-w * 0.05, -h * 0.10, w * 0.25, h * 0.25);
    canvas.drawPath(wingLStroke, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2);
    // منقار
    canvas.drawPath(Path()..moveTo(w * 0.94, h * 0.22)..lineTo(w * 1.12, h * 0.30)..lineTo(w * 0.94, h * 0.38),
        Paint()..color = const Color(0xFFFFA000));
    // چشم
    canvas.drawCircle(Offset(w * 0.82, h * 0.22), w * 0.08, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.83, h * 0.23), w * 0.04, Paint()..color = Colors.black);
    // دم
    final tail = Path()..moveTo(w * 0.20, h * 0.55)..lineTo(w * 0.0, h * 0.85)..lineTo(w * 0.15, h * 0.60);
    canvas.drawPath(tail, body);
  }

  void _drawBat(Canvas canvas, double w, double h) {
    final body = Paint()..color = const Color(0xFF4A148C);
    // بدن
    canvas.drawOval(Rect.fromLTWH(w * 0.30, h * 0.25, w * 0.40, h * 0.50), body);
    // بال‌های خفاش (بالقوه چرم)
    final batWingL = Path()
      ..moveTo(w * 0.30, h * 0.40)
      ..cubicTo(-w * 0.10, h * 0.10, -w * 0.05, h * 0.80, w * 0.30, h * 0.65);
    canvas.drawPath(batWingL, body);
    final batWingR = Path()
      ..moveTo(w * 0.70, h * 0.40)
      ..cubicTo(w * 1.10, h * 0.10, w * 1.05, h * 0.80, w * 0.70, h * 0.65);
    canvas.drawPath(batWingR, body);
    // رگه بال
    canvas.drawPath(batWingL, Paint()..color = const Color(0xFF6A1B9A).withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawPath(batWingR, Paint()..color = const Color(0xFF6A1B9A).withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // سر
    canvas.drawCircle(Offset(w * 0.50, h * 0.28), w * 0.20, body);
    // گوش
    canvas.drawPath(Path()..moveTo(w * 0.36, h * 0.15)..lineTo(w * 0.28, -h * 0.1)..lineTo(w * 0.45, h * 0.15), body);
    canvas.drawPath(Path()..moveTo(w * 0.64, h * 0.15)..lineTo(w * 0.72, -h * 0.1)..lineTo(w * 0.55, h * 0.15), body);
    // چشم‌های قرمز
    canvas.drawCircle(Offset(w * 0.42, h * 0.28), w * 0.07, Paint()..color = const Color(0xFFFF1744));
    canvas.drawCircle(Offset(w * 0.58, h * 0.28), w * 0.07, Paint()..color = const Color(0xFFFF1744));
    // نیش
    canvas.drawLine(Offset(w * 0.45, h * 0.52), Offset(w * 0.43, h * 0.70),
        Paint()..color = Colors.white..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(w * 0.55, h * 0.52), Offset(w * 0.57, h * 0.70),
        Paint()..color = Colors.white..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _drawEagle(Canvas canvas, double w, double h) {
    final body = Paint()..color = const Color(0xFF4E342E);
    final white = Paint()..color = Colors.white;
    // بدن
    canvas.drawOval(Rect.fromLTWH(w * 0.20, h * 0.18, w * 0.60, h * 0.60), body);
    // سر سفید
    canvas.drawCircle(Offset(w * 0.74, h * 0.22), w * 0.22, white);
    // بال‌های بزرگ
    final eWingL = Path()
      ..moveTo(w * 0.20, h * 0.42)
      ..cubicTo(-w * 0.15, h * 0.05, -w * 0.10, h * 0.75, w * 0.22, h * 0.70);
    canvas.drawPath(eWingL, Paint()..color = const Color(0xFF3E2723));
    final eWingR = Path()
      ..moveTo(w * 0.80, h * 0.42)
      ..cubicTo(w * 1.15, h * 0.05, w * 1.10, h * 0.75, w * 0.78, h * 0.70);
    canvas.drawPath(eWingR, Paint()..color = const Color(0xFF3E2723));
    // جزئیات بال
    canvas.drawPath(eWingL, Paint()..color = Colors.brown.shade900..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawPath(eWingR, Paint()..color = Colors.brown.shade900..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // منقار زرد
    canvas.drawPath(
      Path()..moveTo(w * 0.93, h * 0.18)..lineTo(w * 1.15, h * 0.28)..lineTo(w * 0.93, h * 0.35),
      Paint()..color = const Color(0xFFFFB300),
    );
    // چشم
    canvas.drawCircle(Offset(w * 0.80, h * 0.20), w * 0.08, Paint()..color = const Color(0xFFFFD600));
    canvas.drawCircle(Offset(w * 0.80, h * 0.20), w * 0.04, Paint()..color = Colors.black);
    // پنجه
    final clawPaint = Paint()..color = const Color(0xFFFFB300)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(Offset(w * (0.38 + i * 0.12), h), Offset(w * (0.34 + i * 0.12), h * 1.2), clawPaint);
    }
  }

  @override
  bool shouldRepaint(_ObstaclePainter old) => old.type != type;
}

// ============================================
// پس‌زمینه چند بایومی
// ============================================
class _BackgroundPainter extends CustomPainter {
  final double t;
  final List<_Cloud> clouds;
  final List<_Star> stars;
  final List<_Tree> bgTrees;
  final BiomeType biome;
  final double transition;
  _BackgroundPainter(this.t, this.clouds, this.stars, this.bgTrees, this.biome, this.transition);

  List<Color> _skyColors() {
    switch (biome) {
      case BiomeType.night:
        return [const Color(0xFF0D0221), const Color(0xFF1A0040), const Color(0xFF3A0068), const Color(0xFF7B0082)];
      case BiomeType.dawn:
        return [const Color(0xFF0D1B40), const Color(0xFF3D2B5E), const Color(0xFFFF6B35), const Color(0xFFFFD166)];
      case BiomeType.day:
        return [const Color(0xFF1A6BB5), const Color(0xFF4FC3F7), const Color(0xFF81D4FA), const Color(0xFFB3E5FC)];
      case BiomeType.dusk:
        return [const Color(0xFF1A0D2E), const Color(0xFF6B2D6B), const Color(0xFFE57373), const Color(0xFFFFCC80)];
      case BiomeType.storm:
        return [const Color(0xFF1C1C1C), const Color(0xFF37474F), const Color(0xFF546E7A), const Color(0xFF78909C)];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _skyColors();
    final grad = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = grad.createShader(Offset.zero & size));

    // ستاره‌ها فقط شب و گرگ‌ومیش
    final starAlpha = biome == BiomeType.night ? 1.0 : biome == BiomeType.dusk ? 0.5 : biome == BiomeType.storm ? 0.1 : 0.0;
    if (starAlpha > 0) {
      for (final s in stars) {
        final op = (0.3 + 0.7 * sin((t + s.twinklePhase * 3) * 2 * pi)) * starAlpha * transition;
        canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.size,
            Paint()..color = Colors.white.withOpacity(op));
        // درخشش اطراف ستاره بزرگ
        if (s.size > 2.0) {
          canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.size * 3,
              Paint()..color = Colors.white.withOpacity(op * 0.12));
        }
      }
    }

    // ماه یا خورشید
    if (biome == BiomeType.night) {
      _drawMoon(canvas, size);
    } else if (biome == BiomeType.day) {
      _drawSun(canvas, size);
    } else if (biome == BiomeType.dawn || biome == BiomeType.dusk) {
      _drawPartialSun(canvas, size, biome == BiomeType.dawn);
    } else {
      // طوفان: ابر آذرخشی
      _drawStormClouds(canvas, size);
    }

    // ابرها
    for (final c in clouds) {
      _drawCloud(canvas, size, c);
    }

    // درخت‌های پس‌زمینه
    for (final tree in bgTrees) {
      _drawBgTree(canvas, size, tree);
    }

    // کوه‌های دور
    _drawMountains(canvas, size);
  }

  void _drawMoon(Canvas canvas, Size size) {
    final glow = Paint()..color = const Color(0xFFFFF9C4).withOpacity(0.15);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.10), 45, glow);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.10), 30, Paint()..color = const Color(0xFFFFF9C4));
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.08), 23, Paint()..color = const Color(0xFF1A0040));
    // دهانه‌های ماه
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.12), 4, Paint()..color = const Color(0xFFEEE8AA).withOpacity(0.6));
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.09), 3, Paint()..color = const Color(0xFFEEE8AA).withOpacity(0.4));
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.80, size.height * 0.12);
    // تابش
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + t * 0.5;
      canvas.drawLine(
        Offset(center.dx + cos(angle) * 36, center.dy + sin(angle) * 36),
        Offset(center.dx + cos(angle) * 52, center.dy + sin(angle) * 52),
        Paint()..color = const Color(0xFFFFD600).withOpacity(0.7)..strokeWidth = 2.5..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(center, 33, Paint()..color = const Color(0xFFFFD600).withOpacity(0.3));
    canvas.drawCircle(center, 26, Paint()..color = const Color(0xFFFFD600));
    canvas.drawCircle(center, 20, Paint()..color = const Color(0xFFFFF176));
  }

  void _drawPartialSun(Canvas canvas, Size size, bool isDawn) {
    final y = isDawn ? size.height * 0.18 : size.height * 0.15;
    final center = Offset(size.width * 0.75, y);
    canvas.drawCircle(center, 28, Paint()..color = const Color(0xFFFF8F00).withOpacity(0.9));
    canvas.drawCircle(center, 22, Paint()..color = const Color(0xFFFFD600));
    // هاله
    canvas.drawCircle(center, 45, Paint()..color = const Color(0xFFFF8F00).withOpacity(0.2));
  }

  void _drawStormClouds(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF37474F).withOpacity(0.8);
    for (int i = 0; i < 3; i++) {
      final cx = size.width * (0.2 + i * 0.35);
      canvas.drawOval(Rect.fromLTWH(cx, size.height * 0.05, 140, 55), p);
      // آذرخش
      if (i == 1) {
        final bolt = Path()
          ..moveTo(cx + 70, size.height * 0.18)
          ..lineTo(cx + 55, size.height * 0.30)
          ..lineTo(cx + 65, size.height * 0.30)
          ..lineTo(cx + 45, size.height * 0.50);
        canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFFF00).withOpacity(0.9)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      }
    }
  }

  void _drawCloud(Canvas canvas, Size size, _Cloud cloud) {
    final alpha = biome == BiomeType.storm ? 0.6 : 0.18;
    final p = Paint()..color = Colors.white.withOpacity(alpha);
    final cx = cloud.x * size.width;
    final cy = cloud.y * size.height;
    final r = 24.0 * cloud.scale;
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx + r * 0.9, cy - r * 0.25), r * 0.75, p);
    canvas.drawCircle(Offset(cx - r * 0.85, cy - r * 0.1), r * 0.65, p);
    canvas.drawCircle(Offset(cx + r * 1.55, cy + r * 0.1), r * 0.58, p);
    canvas.drawCircle(Offset(cx - r * 0.3, cy - r * 0.4), r * 0.55, p);
  }

  void _drawBgTree(Canvas canvas, Size size, _Tree tree) {
    final x = tree.x * size.width;
    final y = size.height * 0.50;
    final s = tree.scale;

    switch (tree.type) {
      case 0: // درخت کاج بلند
        final tp = Paint()..color = Colors.green.shade900.withOpacity(0.6);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 5 * s, y - 80 * s, 10 * s, 80 * s), const Radius.circular(3)),
            Paint()..color = const Color(0xFF5D4037).withOpacity(0.5));
        for (int i = 0; i < 4; i++) {
          final tPath = Path()
            ..moveTo(x, y - (80 + i * 25) * s)
            ..lineTo(x - (35 - i * 5) * s, y - (55 + i * 25) * s)
            ..lineTo(x + (35 - i * 5) * s, y - (55 + i * 25) * s)
            ..close();
          canvas.drawPath(tPath, tp..color = Colors.green.shade900.withOpacity(0.5 - i * 0.05));
        }
        break;

      case 1: // درخت پهن‌برگ
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 7 * s, y - 70 * s, 14 * s, 70 * s), const Radius.circular(4)),
            Paint()..color = const Color(0xFF5D4037).withOpacity(0.5));
        canvas.drawCircle(Offset(x, y - 80 * s), 40 * s, Paint()..color = Colors.green.shade800.withOpacity(0.55));
        canvas.drawCircle(Offset(x - 20 * s, y - 75 * s), 30 * s, Paint()..color = Colors.green.shade700.withOpacity(0.5));
        canvas.drawCircle(Offset(x + 20 * s, y - 75 * s), 30 * s, Paint()..color = Colors.green.shade700.withOpacity(0.5));
        break;

      case 2: // نخل
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 5 * s, y - 90 * s, 10 * s, 90 * s), const Radius.circular(5)),
            Paint()..color = const Color(0xFF795548).withOpacity(0.6));
        for (int i = 0; i < 6; i++) {
          final angle = (i / 6) * pi * 2;
          final palmLeaf = Path()
            ..moveTo(x, y - 90 * s)
            ..quadraticBezierTo(
              x + cos(angle) * 40 * s, y - 90 * s + sin(angle) * 15 * s,
              x + cos(angle) * 60 * s, y - 75 * s + sin(angle) * 25 * s,
            );
          canvas.drawPath(palmLeaf, Paint()..color = Colors.green.shade600.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 5 * s..strokeCap = StrokeCap.round);
        }
        break;

      case 3: // درخت خزون‌زده
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 6 * s, y - 80 * s, 12 * s, 80 * s), const Radius.circular(4)),
            Paint()..color = const Color(0xFF5D4037).withOpacity(0.55));
        for (int i = 0; i < 5; i++) {
          final angle = (i / 5) * pi;
          canvas.drawLine(
            Offset(x, y - 60 * s),
            Offset(x + cos(angle) * 45 * s, y - 60 * s - sin(angle) * 40 * s),
            Paint()..color = const Color(0xFF6D4C41).withOpacity(0.6)..strokeWidth = 5 * s..strokeCap = StrokeCap.round,
          );
        }
        break;
    }
  }

  void _drawMountains(Canvas canvas, Size size) {
    final mp = Paint()..color = Colors.black.withOpacity(0.15);
    final mPath = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.15, size.height * 0.30)
      ..lineTo(size.width * 0.32, size.height * 0.48)
      ..lineTo(size.width * 0.50, size.height * 0.22)
      ..lineTo(size.width * 0.68, size.height * 0.42)
      ..lineTo(size.width * 0.82, size.height * 0.28)
      ..lineTo(size.width, size.height * 0.45)
      ..lineTo(size.width, size.height * 0.56)
      ..close();
    canvas.drawPath(mPath, mp);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.t != t || old.biome != biome || old.transition != transition;
}

// ============================================
// زمین چندبایومی
// ============================================
class _GroundPainter extends CustomPainter {
  final double offset;
  final BiomeType biome;
  _GroundPainter(this.offset, this.biome);

  @override
  void paint(Canvas canvas, Size size) {
    switch (biome) {
      case BiomeType.night:
      case BiomeType.dusk:
        _drawGrass(canvas, size, const Color(0xFF1B5E20), const Color(0xFF4E342E));
        break;
      case BiomeType.dawn:
        _drawGrass(canvas, size, const Color(0xFF2E7D32), const Color(0xFF5D4037));
        break;
      case BiomeType.day:
        _drawSunnyGrass(canvas, size);
        break;
      case BiomeType.storm:
        _drawWetGround(canvas, size);
        break;
    }
  }

  void _drawGrass(Canvas canvas, Size size, Color grassColor, Color dirtColor) {
    // خاک
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.20, size.width, size.height * 0.80),
        Paint()..color = dirtColor);
    // چمن
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height * 0.22), const Radius.circular(0)),
      Paint()..color = grassColor,
    );
    // خط تیره
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.04),
        Paint()..color = grassColor.withOpacity(0.5));
    // علف‌های کوچک
    final lp = Paint()..color = grassColor.withOpacity(0.7)..strokeWidth = 2..style = PaintingStyle.stroke;
    final spacing = size.width * 0.06;
    final off = (offset * 55) % spacing;
    for (double x = -spacing + off; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, size.height * 0.18), Offset(x - 4, 0), lp);
      canvas.drawLine(Offset(x + 6, size.height * 0.18), Offset(x + 10, 0), lp);
    }
    // سنگ‌ها
    final sp = Paint()..color = dirtColor.withOpacity(0.7);
    for (int i = 0; i < 12; i++) {
      final sx = (i * size.width * 0.10 - (offset * 70) % (size.width * 0.10));
      canvas.drawOval(Rect.fromLTWH(sx, size.height * 0.25, 20, 10), sp);
    }
  }

  void _drawSunnyGrass(Canvas canvas, Size size) {
    // چمن روشن
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.20, size.width, size.height * 0.80),
        Paint()..color = const Color(0xFF795548));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.22),
        Paint()..color = const Color(0xFF4CAF50));
    // گل‌های کوچک
    final spacing = size.width * 0.07;
    final off = (offset * 60) % spacing;
    for (double x = -spacing + off; x < size.width + spacing; x += spacing) {
      canvas.drawCircle(Offset(x, size.height * 0.08),
          4, Paint()..color = const Color(0xFFFFEB3B).withOpacity(0.9));
      canvas.drawCircle(Offset(x + spacing * 0.4, size.height * 0.14),
          3, Paint()..color = const Color(0xFFFF80AB).withOpacity(0.9));
    }
    // خطوط چمن
    final lp = Paint()..color = const Color(0xFF388E3C).withOpacity(0.5)..strokeWidth = 1.5;
    for (double x = -spacing * 0.5 + off; x < size.width + spacing; x += spacing * 0.4) {
      canvas.drawLine(Offset(x, size.height * 0.20), Offset(x + 8, 0), lp);
    }
  }

  void _drawWetGround(Canvas canvas, Size size) {
    // زمین خیس طوفان
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.82),
        Paint()..color = const Color(0xFF37474F));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.20),
        Paint()..color = const Color(0xFF263238));
    // بازتاب آب
    final spacing = size.width * 0.08;
    final off = (offset * 50) % spacing;
    final puddle = Paint()..color = const Color(0xFF546E7A).withOpacity(0.5);
    for (int i = 0; i < 8; i++) {
      final px = (i * size.width * 0.13 - (offset * 60) % (size.width * 0.13));
      canvas.drawOval(Rect.fromLTWH(px, size.height * 0.28, 35, 12), puddle);
    }
    // خط‌های باران روی زمین
    final rp = Paint()..color = Colors.blue.shade900.withOpacity(0.3)..strokeWidth = 1;
    for (double x = -spacing + off; x < size.width + spacing; x += spacing * 0.3) {
      canvas.drawLine(Offset(x, 0), Offset(x - 5, size.height * 0.18), rp);
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.offset != offset || old.biome != biome;
}

// ============================================
// مدل‌ها
// ============================================
class _Obstacle {
  double x;
  final ObstacleType type;
  _Obstacle({required this.x, required this.type});
}

class _Cloud {
  double x, y, scale, speed;
  _Cloud({required this.x, required this.y, required this.scale, required this.speed});
}

class _Star {
  final double x, y, size, twinklePhase;
  _Star({required this.x, required this.y, required this.size, required this.twinklePhase});
}

class _Tree {
  double x, scale;
  int type;
  _Tree({required this.x, required this.scale, required this.type});
}
