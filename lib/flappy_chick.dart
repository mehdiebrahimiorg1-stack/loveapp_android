import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// ════════════════════════════════════════════
//  FLAPPY CHICK — با گرافیک کامل و مراحل
// ════════════════════════════════════════════

class FlappyChickScreen extends StatefulWidget {
  const FlappyChickScreen({super.key});
  @override
  State<FlappyChickScreen> createState() => _FlappyChickState();
}

class _FlappyChickState extends State<FlappyChickScreen>
    with TickerProviderStateMixin {

  // ─── حالت بازی ───
  bool _isPlaying = false;
  bool _isDead = false;
  bool _showGet = false; // نمایش لحظه‌ای "آفرین!"

  int _score = 0;
  int _best = 0;
  int _level = 1;

  // ─── فیزیک مرغ ───
  double _chickY = 0.5;       // نسبت عمودی (0=بالا, 1=پایین)
  double _velocity = 0.0;
  double _gravity = 0.00042;    // گرانش خیلی ملایم
  double _flapForce = -0.0095; // پرش کوچک و نرم
  double _rotation = 0.0;

  // ─── لوله‌ها ───
  List<_Pipe> _pipes = [];
  double _pipeSpeed = 0.0038;
  double _pipeTimer = 0.0;
  double _gapSize = 0.30;     // اندازه شکاف (نسبی)

  // ─── انیمیشن ───
  late AnimationController _wingCtrl;
  late AnimationController _bgCtrl;
  late AnimationController _deathCtrl;
  late AnimationController _scorePopCtrl;
  Timer? _gameTimer;

  // ─── پس‌زمینه ───
  List<_Cloud> _clouds = [];
  List<_Hill> _hills = [];
  final Random _rng = Random();

  // ─── تاریخچه امتیاز ───
  int _passedPipes = 0;

  @override
  void initState() {
    super.initState();
    _wingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))..repeat(reverse: true);
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
    _deathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scorePopCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _initWorld();
  }

  void _initWorld() {
    _clouds = List.generate(6, (i) => _Cloud(
      x: 0.1 + i * 0.18 + _rng.nextDouble() * 0.05,
      y: 0.05 + _rng.nextDouble() * 0.25,
      w: 0.12 + _rng.nextDouble() * 0.10,
      speed: 0.0003 + _rng.nextDouble() * 0.0002,
      opacity: 0.5 + _rng.nextDouble() * 0.5,
    ));
    _hills = List.generate(5, (i) => _Hill(
      x: i * 0.22,
      w: 0.18 + _rng.nextDouble() * 0.08,
      h: 0.06 + _rng.nextDouble() * 0.06,
      color: i % 2 == 0 ? const Color(0xFF4CAF50) : const Color(0xFF388E3C),
    ));
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isDead = false;
      _showGet = false;
      _score = 0;
      _level = 1;
      _passedPipes = 0;
      _chickY = 0.45;
      _velocity = 0.0;
      _rotation = 0.0;
      _pipes = [];
      _pipeTimer = 0;
      _pipeSpeed = 0.0038;
      _gapSize = 0.30;
    });
    _deathCtrl.reset();
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _flap() {
    if (!_isPlaying) { _startGame(); return; }
    if (_isDead) return;
    setState(() {
      _velocity = _flapForce;
      _rotation = -0.25;
    });
    _wingCtrl.forward(from: 0);
  }

  void _tick(Timer t) {
    if (!_isPlaying || _isDead || !mounted) return;
    setState(() {
      // ─── فیزیک ───
      _velocity += _gravity;
      _velocity = _velocity.clamp(-0.018, 0.022); // سرعت محدود — نه خیلی تند
      _chickY += _velocity;
      // چرخش ملایم
      _rotation = (_rotation * 0.85 + _velocity * 8).clamp(-0.4, 1.0);

      // ─── سقف و کف ───
      if (_chickY < 0.03) { _chickY = 0.03; _velocity = 0; }
      if (_chickY > 0.88) { _die(); return; }

      // ─── ابرها حرکت ───
      for (final c in _clouds) {
        c.x -= c.speed * (_pipeSpeed / 0.0038);
        if (c.x < -0.25) {
          c.x = 1.1;
          c.y = 0.05 + _rng.nextDouble() * 0.25;
          c.opacity = 0.5 + _rng.nextDouble() * 0.5;
        }
      }
      for (final h in _hills) {
        h.x -= 0.0006 * (_pipeSpeed / 0.0038);
        if (h.x < -h.w) h.x = 1.02;
      }

      // ─── spawn لوله ───
      _pipeTimer += 0.016;
      if (_pipeTimer > _spawnInterval()) {
        _pipeTimer = 0;
        final gapCenter = 0.22 + _rng.nextDouble() * 0.46;
        _pipes.add(_Pipe(x: 1.05, gapCenter: gapCenter, gap: _gapSize));
      }

      // ─── حرکت لوله‌ها ───
      for (final p in _pipes) {
        p.x -= _pipeSpeed;
        // شمردن عبور
        if (!p.passed && p.x < 0.12) {
          p.passed = true;
          _score++;
          _passedPipes++;
          _scorePopCtrl.forward(from: 0);
          _checkLevel();
        }
      }
      _pipes.removeWhere((p) => p.x < -0.22);

      // ─── برخورد ───
      for (final p in _pipes) {
        if (_hitPipe(p)) { _die(); return; }
      }
    });
  }

  double _spawnInterval() {
    // فاصله spawn کمتر در سطوح بالا، ولی هرگز زیر 1.4 ثانیه
    return (2.2 - (_level - 1) * 0.12).clamp(1.4, 2.2);
  }

  void _checkLevel() {
    // هر ۵ لوله یه سطح
    if (_passedPipes % 5 == 0) {
      _level++;
      _pipeSpeed = (0.0038 + (_level - 1) * 0.00025).clamp(0.0038, 0.0085);
      _gapSize = (0.30 - (_level - 1) * 0.012).clamp(0.18, 0.30);
      _gravity = (0.00042 + (_level - 1) * 0.000015).clamp(0.00042, 0.00065);
    }
  }

  bool _hitPipe(_Pipe p) {
    // هیتباکس جوجه — کمی کوچکتر از گرافیک
    const cx = 0.22;
    final cy = _chickY;
    const r = 0.038; // شعاع جوجه (نسبی)

    final px = p.x;
    const pw = 0.11; // عرض لوله (نسبی)

    if (cx + r < px - pw / 2 || cx - r > px + pw / 2) return false;

    final topEnd = p.gapCenter - p.gap / 2;
    final botStart = p.gapCenter + p.gap / 2;

    return (cy - r < topEnd) || (cy + r > botStart);
  }

  void _die() {
    _isDead = true;
    if (_score > _best) _best = _score;
    _deathCtrl.forward();
    _gameTimer?.cancel();
    _wingCtrl.stop();
  }

  // ─── رنگ آسمون بر اساس سطح ───
  List<Color> _skyColors() {
    switch (_level % 5) {
      case 1: return [const Color(0xFF87CEEB), const Color(0xFFB3E5FC)]; // آبی
      case 2: return [const Color(0xFFFF8C69), const Color(0xFFFFD580)]; // غروب
      case 3: return [const Color(0xFF1A237E), const Color(0xFF283593)]; // شب
      case 4: return [const Color(0xFF4CAF50), const Color(0xFF81C784)]; // جنگل
      case 0: return [const Color(0xFFAB47BC), const Color(0xFFE1BEE7)]; // بنفش
      default: return [const Color(0xFF87CEEB), const Color(0xFFB3E5FC)];
    }
  }

  Color _pipeColor() {
    switch (_level % 5) {
      case 1: return const Color(0xFF2E7D32);
      case 2: return const Color(0xFFBF360C);
      case 3: return const Color(0xFF1565C0);
      case 4: return const Color(0xFF4E342E);
      case 0: return const Color(0xFF6A1B9A);
      default: return const Color(0xFF2E7D32);
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _wingCtrl.dispose();
    _bgCtrl.dispose();
    _deathCtrl.dispose();
    _scorePopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _flap(),
        child: Stack(children: [
          // ─── پس‌زمینه ───
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _BgPainter(_clouds, _hills, _skyColors(), _level),
              size: size,
            ),
          ),
          // ─── لوله‌ها ───
          AnimatedBuilder(
            animation: _wingCtrl,
            builder: (_, __) => CustomPaint(
              painter: _GamePainter(
                pipes: _pipes,
                chickY: _chickY,
                rotation: _rotation,
                wingVal: _wingCtrl.value,
                pipeColor: _pipeColor(),
                isDead: _isDead,
                deathVal: _deathCtrl.value,
                level: _level,
              ),
              size: size,
            ),
          ),
          // ─── زمین ───
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => CustomPaint(
                painter: _GroundPainter(_bgCtrl.value, _pipeSpeed, _level),
                size: Size(size.width, size.height * 0.12),
              ),
            ),
          ),
          // ─── HUD ───
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _hudBox('امتیاز', '$_score', Colors.white),
                    const SizedBox(width: 16),
                    _hudBox('بهترین', '$_best', const Color(0xFFFFD700)),
                    const SizedBox(width: 16),
                    _hudBox('سطح', '$_level', const Color(0xFF80DEEA)),
                  ],
                ),
              ],
            ),
          ),
          // ─── پاپ امتیاز ───
          if (_isPlaying && !_isDead)
            AnimatedBuilder(
              animation: _scorePopCtrl,
              builder: (_, __) {
                final v = _scorePopCtrl.value;
                return Positioned(
                  top: size.height * 0.18 - v * 40,
                  left: 0, right: 0,
                  child: Opacity(
                    opacity: v < 0.5 ? v * 2 : (1 - v) * 2,
                    child: Center(
                      child: Text('+1',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                          )),
                    ),
                  ),
                );
              },
            ),
          // ─── صفحه شروع ───
          if (!_isPlaying && !_isDead) _buildStart(size),
          // ─── صفحه مرگ ───
          if (_isDead) _buildDead(size),
        ]),
      ),
    );
  }

  Widget _hudBox(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
      ]),
    );
  }

  Widget _buildStart(Size size) {
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🐥', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 12),
          const Text('Flappy Chick',
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white,
                  shadows: [Shadow(color: Colors.orange, blurRadius: 20)])),
          const SizedBox(height: 10),
          Text('بهترین: $_best',
              style: const TextStyle(fontSize: 18, color: Colors.white70)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFFF6D00)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 16)],
            ),
            child: const Text('ضربه بزن!', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _buildDead(Size size) {
    final isNewBest = _score >= _best && _score > 0;
    return AnimatedBuilder(
      animation: _deathCtrl,
      builder: (_, __) => Opacity(
        opacity: _deathCtrl.value.clamp(0, 1),
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 30)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(isNewBest ? '🏆' : '💔', style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 4),
                Text(isNewBest ? 'رکورد جدید!' : 'تموم شد!',
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                      color: isNewBest ? const Color(0xFFFF8F00) : Colors.red,
                    )),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _resultBox('امتیاز', '$_score', Colors.blue),
                  _resultBox('بهترین', '$_best', const Color(0xFFFF8F00)),
                  _resultBox('سطح', '$_level', Colors.purple),
                ]),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 12)],
                    ),
                    child: const Text('دوباره! 🐥',
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBox(String label, String val, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
      Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

// ════════════════════════════════════════════
//  پس‌زمینه
// ════════════════════════════════════════════
class _BgPainter extends CustomPainter {
  final List<_Cloud> clouds;
  final List<_Hill> hills;
  final List<Color> skyColors;
  final int level;
  _BgPainter(this.clouds, this.hills, this.skyColors, this.level);

  @override
  void paint(Canvas canvas, Size size) {
    // آسمون
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: skyColors,
      ).createShader(Offset.zero & size),
    );

    // ستاره‌ها شب
    if (level % 5 == 3) {
      final sp = Paint()..color = Colors.white.withOpacity(0.8);
      final rng = Random(42);
      for (int i = 0; i < 40; i++) {
        canvas.drawCircle(
          Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.7),
          rng.nextDouble() * 2 + 0.5, sp,
        );
      }
    }

    // ابرها
    for (final c in clouds) {
      _drawCloud(canvas, size, c);
    }

    // تپه‌ها
    for (final h in hills) {
      final cx = h.x * size.width + h.w * size.width / 2;
      final base = size.height * 0.88;
      final hp = h.h * size.height;
      final wp = h.w * size.width;
      final path = Path()
        ..moveTo(cx - wp * 0.55, base)
        ..quadraticBezierTo(cx, base - hp, cx + wp * 0.55, base)
        ..close();
      canvas.drawPath(path, Paint()..color = h.color.withOpacity(0.7));
      // خط روشن تپه
      canvas.drawPath(path, Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
  }

  void _drawCloud(Canvas canvas, Size size, _Cloud c) {
    final cx = c.x * size.width;
    final cy = c.y * size.height;
    final r = c.w * size.width * 0.38;
    final p = Paint()..color = Colors.white.withOpacity(c.opacity * 0.72);
    canvas.drawCircle(Offset(cx, cy), r, p);
    canvas.drawCircle(Offset(cx + r * 0.8, cy + r * 0.15), r * 0.72, p);
    canvas.drawCircle(Offset(cx - r * 0.75, cy + r * 0.18), r * 0.65, p);
    canvas.drawCircle(Offset(cx + r * 0.2, cy - r * 0.28), r * 0.58, p);
    // درخشش
    canvas.drawCircle(Offset(cx - r * 0.2, cy - r * 0.1), r * 0.28,
        Paint()..color = Colors.white.withOpacity(c.opacity * 0.35));
  }

  @override
  bool shouldRepaint(_BgPainter old) => true;
}

// ════════════════════════════════════════════
//  بازی اصلی — لوله‌ها + جوجه
// ════════════════════════════════════════════
class _GamePainter extends CustomPainter {
  final List<_Pipe> pipes;
  final double chickY, rotation, wingVal, deathVal;
  final Color pipeColor;
  final bool isDead;
  final int level;
  _GamePainter({
    required this.pipes, required this.chickY, required this.rotation,
    required this.wingVal, required this.pipeColor, required this.isDead,
    required this.deathVal, required this.level,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // زمین خط
    final groundY = size.height * 0.88;

    // لوله‌ها
    for (final p in pipes) {
      _drawPipe(canvas, size, p, groundY);
    }

    // جوجه
    _drawChick(canvas, size, groundY);
  }

  void _drawPipe(Canvas canvas, Size size, _Pipe p, double groundY) {
    final cx = p.x * size.width;
    final pw = 0.11 * size.width;
    final topEnd = p.gapCenter * groundY - p.gap / 2 * groundY;
    final botStart = p.gapCenter * groundY + p.gap / 2 * groundY;

    // ─── لوله پایین ───
    _drawPipeBody(canvas, Rect.fromLTWH(cx - pw / 2, botStart, pw, groundY - botStart));
    _drawPipeCap(canvas, Rect.fromLTWH(cx - pw / 2 - 5, botStart, pw + 10, pw * 0.35), false);

    // ─── لوله بالا ───
    _drawPipeBody(canvas, Rect.fromLTWH(cx - pw / 2, 0, pw, topEnd));
    _drawPipeCap(canvas, Rect.fromLTWH(cx - pw / 2 - 5, topEnd - pw * 0.35, pw + 10, pw * 0.35), true);
  }

  void _drawPipeBody(Canvas canvas, Rect rect) {
    if (rect.height <= 0) return;
    // بدنه اصلی
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rr, Paint()..color = pipeColor);
    // نوار روشن چپ
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 4, rect.top, rect.width * 0.22, rect.height), const Radius.circular(3)),
      Paint()..color = Colors.white.withOpacity(0.22),
    );
    // نوار تیره راست
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.right - rect.width * 0.18, rect.top, rect.width * 0.18, rect.height), const Radius.circular(2)),
      Paint()..color = Colors.black.withOpacity(0.18),
    );
    // لبه
    canvas.drawRRect(rr, Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  void _drawPipeCap(Canvas canvas, Rect rect, bool isTop) {
    if (rect.height <= 0) return;
    final capColor = HSLColor.fromColor(pipeColor).withLightness(
      (HSLColor.fromColor(pipeColor).lightness + 0.08).clamp(0.0, 1.0)
    ).toColor();
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rr, Paint()..color = capColor);
    // درخشش روی کپ
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.left + 5, rect.top + 3, rect.width * 0.35, rect.height * 0.45), const Radius.circular(4)),
      Paint()..color = Colors.white.withOpacity(0.28),
    );
    canvas.drawRRect(rr, Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  void _drawChick(Canvas canvas, Size size, double groundY) {
    const cx = 0.22;
    final cy = chickY;
    final x = cx * size.width;
    final y = cy * groundY;

    canvas.save();
    canvas.translate(x, y);

    // شیک هنگام مرگ
    if (isDead) {
      canvas.rotate(deathVal * pi * 0.5);
    } else {
      canvas.rotate(rotation);
    }

    final w = size.width * 0.085;
    final h = w * 1.15;

    // ─── سایه ───
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.1, h * 0.7), width: w * 1.2, height: h * 0.15),
      Paint()..color = Colors.black.withOpacity(0.13),
    );

    // ─── دم ───
    _drawTail(canvas, w, h);

    // ─── بدن ───
    final bodyRect = Rect.fromCenter(center: Offset(0, 0), width: w, height: h);
    final bodyGrad = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.7,
      colors: [const Color(0xFFFFF9C4), const Color(0xFFFFEA00), const Color(0xFFFFB300)],
    );
    canvas.drawOval(bodyRect, Paint()..shader = bodyGrad.createShader(bodyRect));
    canvas.drawOval(bodyRect, Paint()
      ..color = const Color(0xFFFF8F00).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // ─── پرهای بدن ───
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-w * 0.35 + i * w * 0.28, h * (-0.1 + i * 0.15)),
        Offset(w * 0.3 - i * w * 0.05, h * (-0.1 + i * 0.15) + 2),
        Paint()..color = const Color(0xFFFFB300).withOpacity(0.22)..strokeWidth = 1.5,
      );
    }

    // ─── سینه ───
    final bellyRect = Rect.fromCenter(center: Offset(w * 0.12, h * 0.08), width: w * 0.55, height: h * 0.62);
    canvas.drawOval(bellyRect, Paint()..color = const Color(0xFFFFFDE7).withOpacity(0.88));

    // ─── بال ───
    _drawWing(canvas, w, h, wingVal);

    // ─── سر ───
    final headRect = Rect.fromCenter(center: Offset(w * 0.22, -h * 0.40), width: w * 0.80, height: h * 0.70);
    final headGrad = RadialGradient(
      center: const Alignment(-0.2, -0.35),
      radius: 0.65,
      colors: [const Color(0xFFFFFDE7), const Color(0xFFFFEA00), const Color(0xFFFFB300)],
    );
    canvas.drawOval(headRect, Paint()..shader = headGrad.createShader(headRect));
    canvas.drawOval(headRect, Paint()
      ..color = const Color(0xFFFF8F00).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    // نور سر
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.10, -h * 0.52), width: w * 0.28, height: h * 0.18),
      Paint()..color = Colors.white.withOpacity(0.35),
    );

    // ─── تاج ───
    _drawCrown(canvas, w, h);

    // ─── منقار ───
    final beakPath = Path()
      ..moveTo(w * 0.55, -h * 0.40)
      ..cubicTo(w * 0.78, -h * 0.38, w * 0.90, -h * 0.34, w * 0.88, -h * 0.30)
      ..cubicTo(w * 0.90, -h * 0.26, w * 0.78, -h * 0.22, w * 0.55, -h * 0.22)
      ..close();
    canvas.drawPath(beakPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFFFFB300), const Color(0xFFE65100)],
      ).createShader(Rect.fromLTWH(w * 0.5, -h * 0.42, w * 0.45, h * 0.24)));
    canvas.drawLine(
      Offset(w * 0.56, -h * 0.31),
      Offset(w * 0.87, -h * 0.31),
      Paint()..color = const Color(0xFFC43E00).withOpacity(0.55)..strokeWidth = 1.1,
    );

    // ─── چشم ───
    _drawEye(canvas, w, h);

    // ─── گونه ───
    canvas.drawCircle(Offset(w * 0.36, -h * 0.24), w * 0.11,
        Paint()..color = const Color(0xFFFF80AB).withOpacity(0.55));

    // ─── پاها ───
    _drawLegs(canvas, w, h);

    canvas.restore();
  }

  void _drawTail(Canvas canvas, double w, double h) {
    final colors = [const Color(0xFFFFCA28), const Color(0xFFFFE082), const Color(0xFFFFA000)];
    for (int i = 0; i < 3; i++) {
      final angle = (0.55 + i * 0.22) * pi;
      final tp = Path()
        ..moveTo(-w * 0.42, h * 0.05)
        ..quadraticBezierTo(
          -w * 0.42 - cos(angle) * w * 0.45,
          h * 0.05 - sin(angle) * h * 0.30,
          -w * 0.42 - cos(angle) * w * 0.62,
          h * 0.05 - sin(angle) * h * 0.42,
        );
      canvas.drawPath(tp, Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = (7 - i * 1.2)
        ..strokeCap = StrokeCap.round);
    }
  }

  void _drawWing(Canvas canvas, double w, double h, double wv) {
    final open = wv * 0.5 + 0.1;
    final wingPath = Path()
      ..moveTo(-w * 0.30, -h * 0.05)
      ..quadraticBezierTo(-w * 0.55, -h * 0.10 - open * h * 0.25, -w * 0.65, h * 0.08 + open * h * 0.20)
      ..quadraticBezierTo(-w * 0.40, h * 0.22, -w * 0.22, h * 0.10)
      ..close();
    canvas.drawPath(wingPath, Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFFFCA28), const Color(0xFFFF8F00)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(-w * 0.7, -h * 0.35, w * 0.55, h * 0.6)));
    canvas.drawPath(wingPath, Paint()
      ..color = const Color(0xFFFF8F00).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    // پرهای بال
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-w * (0.35 + i * 0.09), h * 0.04),
        Offset(-w * (0.38 + i * 0.12), h * (0.16 + open * 0.12 + i * 0.04)),
        Paint()..color = const Color(0xFFFFA000).withOpacity(0.65)..strokeWidth = 2.2..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawCrown(Canvas canvas, double w, double h) {
    final angles = [-pi * 0.55, -pi * 0.65, -pi * 0.45, -pi * 0.72, -pi * 0.38];
    final lens = [w * 0.30, w * 0.24, w * 0.26, w * 0.18, w * 0.18];
    final cols = [const Color(0xFFFFD600), const Color(0xFFFF6D00), const Color(0xFFFFD600), const Color(0xFFFF6D00), const Color(0xFFFF8F00)];
    final base = Offset(w * 0.20, -h * 0.75);
    for (int i = 0; i < 5; i++) {
      final tip = Offset(base.dx + cos(angles[i]) * lens[i], base.dy + sin(angles[i]) * lens[i]);
      canvas.drawLine(base, tip, Paint()..color = cols[i]..strokeWidth = 6..strokeCap = StrokeCap.round);
      canvas.drawCircle(tip, 3.8, Paint()..color = cols[(i + 1) % cols.length]);
    }
  }

  void _drawEye(Canvas canvas, double w, double h) {
    final ec = Offset(w * 0.38, -h * 0.42);
    canvas.drawCircle(ec, w * 0.175, Paint()..color = Colors.black.withOpacity(0.12));
    canvas.drawCircle(ec, w * 0.160, Paint()..color = Colors.white);
    canvas.drawCircle(ec, w * 0.112, Paint()..color = const Color(0xFF1A237E));
    canvas.drawCircle(ec, w * 0.068, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(ec.dx - w * 0.038, ec.dy - w * 0.038), w * 0.038, Paint()..color = Colors.white.withOpacity(0.95));
    canvas.drawCircle(Offset(ec.dx + w * 0.028, ec.dy + w * 0.016), w * 0.016, Paint()..color = Colors.white.withOpacity(0.7));
    // مژه
    for (int i = 0; i < 4; i++) {
      final a = -pi * 0.80 + i * 0.22;
      canvas.drawLine(
        Offset(ec.dx + cos(a) * w * 0.155, ec.dy + sin(a) * w * 0.155),
        Offset(ec.dx + cos(a) * w * 0.22, ec.dy + sin(a) * w * 0.22),
        Paint()..color = Colors.black87..strokeWidth = 1.8..strokeCap = StrokeCap.round,
      );
    }
    // ابرو
    canvas.drawLine(
      Offset(ec.dx - w * 0.11, ec.dy - w * 0.175),
      Offset(ec.dx + w * 0.09, ec.dy - w * 0.20),
      Paint()..color = const Color(0xFFFFA000)..strokeWidth = 2.5..strokeCap = StrokeCap.round,
    );
  }

  void _drawLegs(Canvas canvas, double w, double h) {
    final lp = Paint()..color = const Color(0xFFFF8F00)..strokeWidth = 4..strokeCap = StrokeCap.round;
    final tp = Paint()..color = const Color(0xFFE65100)..strokeWidth = 2.8..strokeCap = StrokeCap.round;
    // پای جلو
    canvas.drawLine(Offset(w * 0.08, h * 0.52), Offset(w * 0.14, h * 0.72), lp);
    canvas.drawLine(Offset(w * 0.14, h * 0.72), Offset(w * 0.30, h * 0.72), tp);
    canvas.drawLine(Offset(w * 0.14, h * 0.72), Offset(w * 0.06, h * 0.76), tp);
    // پای عقب
    canvas.drawLine(Offset(-w * 0.08, h * 0.52), Offset(-w * 0.04, h * 0.72), lp..color = const Color(0xFFFF8F00).withOpacity(0.72));
    canvas.drawLine(Offset(-w * 0.04, h * 0.72), Offset(w * 0.12, h * 0.72), tp..color = const Color(0xFFE65100).withOpacity(0.72));
    canvas.drawLine(Offset(-w * 0.04, h * 0.72), Offset(-w * 0.12, h * 0.76), tp..color = const Color(0xFFE65100).withOpacity(0.72));
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}

// ════════════════════════════════════════════
//  زمین
// ════════════════════════════════════════════
class _GroundPainter extends CustomPainter {
  final double t;
  final double speed;
  final int level;
  _GroundPainter(this.t, this.speed, this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final groundColors = [
      [const Color(0xFF8D6E63), const Color(0xFF6D4C41)],
      [const Color(0xFF5D4037), const Color(0xFF3E2723)],
      [const Color(0xFF1A237E), const Color(0xFF0D47A1)],
      [const Color(0xFF33691E), const Color(0xFF1B5E20)],
      [const Color(0xFF4A148C), const Color(0xFF311B92)],
    ];
    final cols = groundColors[(level - 1) % groundColors.length];

    // بدنه زمین
    canvas.drawRect(Offset.zero & size, Paint()..color = cols[0]);

    // خطوط حرکت
    final off = (t * speed * 1200) % 60;
    final lp = Paint()..color = cols[1]..strokeWidth = 2;
    for (double x = -60 + off; x < size.width + 60; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lp);
    }

    // خط بالایی
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 5),
        Paint()..color = cols[1]);
    // نور بالا
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 2),
        Paint()..color = Colors.white.withOpacity(0.18));
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.t != t;
}

// ════════════════════════════════════════════
//  مدل‌ها
// ════════════════════════════════════════════
class _Pipe {
  double x;
  final double gapCenter;
  final double gap;
  bool passed = false;
  _Pipe({required this.x, required this.gapCenter, required this.gap});
}

class _Cloud {
  double x, y, w, speed, opacity;
  _Cloud({required this.x, required this.y, required this.w, required this.speed, required this.opacity});
}

class _Hill {
  double x, w, h;
  Color color;
  _Hill({required this.x, required this.w, required this.h, required this.color});
}
