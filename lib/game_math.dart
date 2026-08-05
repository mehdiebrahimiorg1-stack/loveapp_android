import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// ============================================
// مدل سوال
// ============================================
class _Question {
  final String question;
  final List<String> options;
  final int correctIndex;

  const _Question({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

// ============================================
// ۳۰ لول سوال ریاضی
// ============================================
final List<_Question> _allQuestions = [
  // لول ۱-۵ — جمع ساده
  _Question(question: '1 - 2 = ?', options: ['1', '2', '3'], correctIndex: 0),
  _Question(question: '3 + 1 = ?', options: ['5', '4', '3'], correctIndex: 1),
  _Question(question: '2 + 3 - 1 = ?', options: ['5', '3', '4'], correctIndex: 2),
  _Question(question: '5 - 2 + 1 = ?', options: ['3', '4', '5'], correctIndex: 1),
  _Question(question: '4 + 2 - 3 = ?', options: ['2', '3', '4'], correctIndex: 1),

  // لول ۶-۱۰ — جمع متوسط
  _Question(question: '6 - 1 + 2 = ?', options: ['6', '7', '8'], correctIndex: 1),
  _Question(question: '3 + 4 - 2 = ?', options: ['4', '5', '6'], correctIndex: 1),
  _Question(question: '1 - 3 x 3 = ?', options: ['4', '5', '6'], correctIndex: 2),
  _Question(question: '5 + 3 - 4 = ?', options: ['3', '4', '5'], correctIndex: 1),
  _Question(question: '2 x 3 + 1 = ?', options: ['6', '7', '8'], correctIndex: 1),

  // لول ۱۱-۱۵ — تفریق
  _Question(question: '8 - 2 x 2 = ?', options: ['12', '13', '8'], correctIndex: 0),
  _Question(question: '4 x 2 + 3 = ?', options: ['10', '11', '12'], correctIndex: 1),
  _Question(question: '10 + 5 - 7 = ?', options: ['8', '7', '9'], correctIndex: 0),
  _Question(question: '3 x 4 x 2 = ?', options: ['12', '24', '22'], correctIndex: 1),
  _Question(question: '12 ÷ 3 + 3 = ?', options: ['7', '6', '8'], correctIndex: 0),

  // لول ۱۶-۲۰ — ضرب
  _Question(question: '15 - 6 + 2 = ?', options: ['11', '12', '9'], correctIndex: 0),
  _Question(question: '5 × 3 x 2 - 5 = ?', options: ['25', '26', '30'], correctIndex: 0),
  _Question(question: '18 ÷ 3 x 3 = ?', options: ['18', '24', '9'], correctIndex: 0),
  _Question(question: '9 × 6 + 1 = ?', options: ['52', '54', '55'], correctIndex: 1),
  _Question(question: '12 + 17 - 1 + 4 = ?', options: ['32', '33', '31'], correctIndex: 0),

  // لول ۲۱-۲۵ — تقسیم
  _Question(question: '24 ÷ 3 + 8 = ?', options: ['16', '17', '8'], correctIndex: 0),
  _Question(question: '36 ÷ 6 ÷ 2 + 1 = ?', options: ['3', '6', '4'], correctIndex: 2),
  _Question(question: '9 x 9 ÷ 9 + 9 = ?', options: ['9', '0', '18'], correctIndex: 2),
  _Question(question: '28 + 46 + 13 = ?', options: ['88', '87', '89'], correctIndex: 1),
  _Question(question: '84 - 7 x 2 = ?', options: ['154', '140', '130'], correctIndex: 0),

  // لول ۲۶-۳۰ — توان + ترکیبی سخت
  _Question(question: '2² + 23 = ?', options: ['27', '24', '28'], correctIndex: 0),
  _Question(question: '3² - 7 x 2 = ?', options: ['8', '4', '16'], correctIndex: 1),
  _Question(question: '2³ - 8 x 1 = ?', options: ['0', '1', '8'], correctIndex: 0),
  _Question(question: '4² + 3 ÷ 2= ?', options: ['8', '19', '9'], correctIndex: 0),
  _Question(question: '(5 × 4) - 2³ = ?', options: ['10', '12', '14'], correctIndex: 1),
];

// ============================================
// صفحه بازی ریاضی
// ============================================
class GameMathScreen extends StatefulWidget {
  const GameMathScreen({super.key});
  @override
  State<GameMathScreen> createState() => _GameMathScreenState();
}

class _GameMathScreenState extends State<GameMathScreen>
    with TickerProviderStateMixin {
  int _currentLevel = 0;
  int _score = 0;
  int _stars = 3;
  int _timeLeft = 10;
  bool _gameOver = false;
  bool _won = false;
  int? _selectedOption;
  bool _answered = false;

  Timer? _timer;

  late AnimationController _starBurnCtrl;
  late AnimationController _timerCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _starBurnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _starBurnCtrl.dispose();
    _timerCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = 10;
    _timer?.cancel();
    _timerCtrl.reset();
    _timerCtrl.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    if (_answered) return;
    _loseStarAndContinue();
  }

  void _selectOption(int idx) {
    if (_answered) return;
    _timer?.cancel();
    setState(() {
      _selectedOption = idx;
      _answered = true;
    });

    final q = _allQuestions[_currentLevel];
    if (idx == q.correctIndex) {
      _score += _timeLeft * 10 + 10;
      Future.delayed(const Duration(milliseconds: 800), _nextLevel);
    } else {
      _shakeCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 600), _loseStarAndContinue);
    }
  }

  void _loseStarAndContinue() {
    if (!mounted) return;
    _starBurnCtrl.forward(from: 0);
    setState(() => _stars--);

    if (_stars <= 0) {
      setState(() => _gameOver = true);
    } else {
      Future.delayed(const Duration(milliseconds: 500), _nextLevelSame);
    }
  }

  void _nextLevel() {
    if (!mounted) return;
    if (_currentLevel >= _allQuestions.length - 1) {
      setState(() { _won = true; _gameOver = true; });
      return;
    }
    setState(() {
      _currentLevel++;
      _selectedOption = null;
      _answered = false;
    });
    _startTimer();
  }

  void _nextLevelSame() {
    if (!mounted) return;
    setState(() {
      _selectedOption = null;
      _answered = false;
    });
    _startTimer();
  }

  void _restart() {
    setState(() {
      _currentLevel = 0;
      _score = 0;
      _stars = 3;
      _timeLeft = 10;
      _gameOver = false;
      _won = false;
      _selectedOption = null;
      _answered = false;
    });
    _startTimer();
  }

  Color _optionColor(int idx) {
    if (!_answered) return Colors.white;
    final q = _allQuestions[_currentLevel];
    if (idx == q.correctIndex) return Colors.green[100]!;
    if (idx == _selectedOption) return Colors.red[100]!;
    return Colors.white;
  }

  Color _optionBorder(int idx) {
    if (!_answered) return Colors.pink[200]!;
    final q = _allQuestions[_currentLevel];
    if (idx == q.correctIndex) return Colors.green;
    if (idx == _selectedOption) return Colors.red;
    return Colors.pink[200]!;
  }

  IconData _optionIcon(int idx) {
    if (!_answered) return Icons.circle_outlined;
    final q = _allQuestions[_currentLevel];
    if (idx == q.correctIndex) return Icons.check_circle;
    if (idx == _selectedOption) return Icons.cancel;
    return Icons.circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final q = _allQuestions[_currentLevel];

    return Scaffold(
      body: Stack(
        children: [
          // بک‌گراند
          _MathBackground(),

          SafeArea(
            child: _gameOver
                ? _buildGameOver()
                : Column(
                    children: [
                      // هدر
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text('بازی ریاضی 🧮',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const Spacer(),
                            // امتیاز
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('امتیاز: $_score',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),

                      // ستاره‌ها
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final active = i < _stars;
                          return AnimatedScale(
                            scale: active ? 1.0 : 0.7,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              active ? Icons.star : Icons.star_outline,
                              color: active ? Colors.amber : Colors.white30,
                              size: 40,
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 8),

                      // لول
                      Text(
                        'لول ${_currentLevel + 1} از ${_allQuestions.length}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),

                      const SizedBox(height: 16),

                      // تایمر
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.timer,
                                    color: Colors.white70, size: 18),
                                Text('$_timeLeft ثانیه',
                                    style: TextStyle(
                                        color: _timeLeft <= 3
                                            ? Colors.red[200]
                                            : Colors.white70,
                                        fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            AnimatedBuilder(
                              animation: _timerCtrl,
                              builder: (_, __) => ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: 1 - _timerCtrl.value,
                                  minHeight: 8,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _timeLeft <= 3
                                        ? Colors.red[300]!
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // کارت سوال
                      AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: child,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(
                              vertical: 32, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink[900]!.withOpacity(0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              q.question,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                      color: Colors.black26, blurRadius: 8)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // گزینه‌ها
                      ...List.generate(q.options.length, (idx) {
                        return GestureDetector(
                          onTap: () => _selectOption(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              color: _optionColor(idx),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _optionBorder(idx), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(_optionIcon(idx),
                                    color: _answered
                                        ? _optionBorder(idx)
                                        : Colors.pink[300],
                                    size: 22),
                                const SizedBox(width: 16),
                                Text(
                                  q.options[idx],
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _answered
                                        ? _optionBorder(idx)
                                        : Colors.pink[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.pink.withOpacity(0.4), blurRadius: 30)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _won ? '🎉 برنده شدی!' : '💔 باختی!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _won ? Colors.green[700] : Colors.pink[700],
              ),
            ),
            const SizedBox(height: 16),
            // ستاره‌های نهایی
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Icon(
                i < _stars ? Icons.star : Icons.star_outline,
                color: i < _stars ? Colors.amber : Colors.grey[300],
                size: 36,
              )),
            ),
            const SizedBox(height: 16),
            Text(
              'لول رسیدی: ${_currentLevel + 1}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'امتیاز نهایی: $_score',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _restart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('دوباره بازی کن! ❤️',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// بک‌گراند بازی ریاضی
// ============================================
class _MathBackground extends StatefulWidget {
  @override
  State<_MathBackground> createState() => _MathBackgroundState();
}

class _MathBackgroundState extends State<_MathBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _MathPainter(_ctrl.value),
        child: Container(),
        size: Size.infinite,
      ),
    );
  }
}

class _MathPainter extends CustomPainter {
  final double t;
  _MathPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF6A1B9A),
        const Color(0xFF8E24AA),
        const Color(0xFFAD1457),
        const Color(0xFFC2185B),
      ],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = grad.createShader(Offset.zero & size),
    );

    // نمادهای ریاضی شناور
    final symbols = ['+', '−', '×', '÷', '=', '²', '³', '?'];
    final positions = [
      [0.1, 0.1], [0.4, 0.05], [0.7, 0.12], [0.9, 0.08],
      [0.05, 0.4], [0.3, 0.3], [0.65, 0.35], [0.85, 0.45],
      [0.15, 0.65], [0.5, 0.6], [0.8, 0.7], [0.25, 0.8],
      [0.6, 0.85], [0.9, 0.78], [0.4, 0.92], [0.1, 0.88],
    ];

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final phase = (t + i * 0.07) % 1.0;
      final opacity = 0.06 + 0.06 * sin(phase * 2 * pi);
      final yOffset = sin((t + i * 0.1) * 2 * pi) * 8;

      textPainter.text = TextSpan(
        text: symbols[i % symbols.length],
        style: TextStyle(
          fontSize: 22,
          color: Colors.white.withOpacity(opacity),
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          pos[0] * size.width,
          pos[1] * size.height + yOffset,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_MathPainter old) => old.t != t;
}
