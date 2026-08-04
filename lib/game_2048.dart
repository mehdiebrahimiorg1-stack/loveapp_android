import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});
  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<Game2048Screen>
    with TickerProviderStateMixin {
  static const int size = 4;
  List<List<int>> board = [];
  int score = 0;
  List<List<List<int>>> history = [];
  bool _gameOver = false;

  // انیمیشن
  late AnimationController _moveController;
  List<_TileAnim> _animTiles = [];

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _initBoard();
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  void _initBoard() {
    board = List.generate(size, (_) => List.filled(size, 0));
    score = 0;
    history = [];
    _gameOver = false;
    _animTiles = [];
    _addRandom();
    _addRandom();
    _buildStaticTiles();
  }

  void _buildStaticTiles() {
    _animTiles = [];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] != 0) {
          _animTiles.add(_TileAnim(
            value: board[r][c],
            fromRow: r, fromCol: c,
            toRow: r, toCol: c,
          ));
        }
      }
    }
  }

  void _addRandom() {
    final empty = <List<int>>[];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] == 0) empty.add([r, c]);
      }
    }
    if (empty.isEmpty) return;
    final pos = empty[Random().nextInt(empty.length)];
    board[pos[0]][pos[1]] = Random().nextInt(10) < 9 ? 2 : 4;
  }

  List<List<int>> _copyBoard() =>
      board.map((r) => List<int>.from(r)).toList();

  void _saveHistory() {
    history.add(_copyBoard());
    if (history.length > 2) history.removeAt(0);
  }

  void _undo() {
    if (history.isEmpty) return;
    setState(() {
      board = history.removeLast();
      _gameOver = false;
      _buildStaticTiles();
    });
  }

  // حرکت یه ردیف به چپ + برگشت مسیر هر تایل
  _MergeResult _mergeLeft(List<int> row) {
    final moves = <_TileMove>[];
    List<int> filtered = [];
    List<int> origIdx = [];

    for (int i = 0; i < row.length; i++) {
      if (row[i] != 0) { filtered.add(row[i]); origIdx.add(i); }
    }

    List<int> result = [];
    List<int> srcIdx = [];
    int i = 0;
    while (i < filtered.length) {
      if (i + 1 < filtered.length && filtered[i] == filtered[i + 1]) {
        result.add(filtered[i] * 2);
        srcIdx.add(origIdx[i]);
        // هر دو کاشی merge شدن
        moves.add(_TileMove(from: origIdx[i], to: result.length - 1, value: filtered[i], merged: false));
        moves.add(_TileMove(from: origIdx[i + 1], to: result.length - 1, value: filtered[i + 1], merged: true));
        i += 2;
      } else {
        result.add(filtered[i]);
        srcIdx.add(origIdx[i]);
        moves.add(_TileMove(from: origIdx[i], to: result.length - 1, value: filtered[i], merged: false));
        i++;
      }
    }

    while (result.length < size) result.add(0);
    return _MergeResult(row: result, moves: moves);
  }

  Future<void> _move(String dir) async {
    _saveHistory();
    final prev = _copyBoard();
    final newBoard = _copyBoard();
    final List<_TileAnim> animTiles = [];
    int addedScore = 0;

    if (dir == 'left' || dir == 'right') {
      for (int r = 0; r < size; r++) {
        List<int> row = List.from(newBoard[r]);
        bool reversed = dir == 'right';
        if (reversed) row = row.reversed.toList();
        final res = _mergeLeft(row);
        for (final m in res.moves) {
          final fromC = reversed ? (size - 1 - m.from) : m.from;
          final toC = reversed ? (size - 1 - m.to) : m.to;
          animTiles.add(_TileAnim(
            value: m.value,
            fromRow: r, fromCol: fromC,
            toRow: r, toCol: toC,
            merged: m.merged,
          ));
        }
        if (reversed) {
          newBoard[r] = res.row.reversed.toList();
        } else {
          newBoard[r] = res.row;
        }
      }
    } else {
      for (int c = 0; c < size; c++) {
        List<int> col = List.generate(size, (r) => newBoard[r][c]);
        bool reversed = dir == 'down';
        if (reversed) col = col.reversed.toList();
        final res = _mergeLeft(col);
        for (final m in res.moves) {
          final fromR = reversed ? (size - 1 - m.from) : m.from;
          final toR = reversed ? (size - 1 - m.to) : m.to;
          animTiles.add(_TileAnim(
            value: m.value,
            fromRow: fromR, fromCol: c,
            toRow: toR, toCol: c,
            merged: m.merged,
          ));
        }
        if (reversed) {
          for (int r = 0; r < size; r++) newBoard[r][c] = res.row.reversed.toList()[r];
        } else {
          for (int r = 0; r < size; r++) newBoard[r][c] = res.row[r];
        }
      }
    }

    bool moved = false;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (newBoard[r][c] != prev[r][c]) { moved = true; break; }
      }
      if (moved) break;
    }

    if (!moved) { history.removeLast(); return; }

    // محاسبه امتیاز
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (newBoard[r][c] > prev[r][c]) addedScore += newBoard[r][c];
      }
    }

    setState(() {
      _animTiles = animTiles;
    });

    _moveController.reset();
    await _moveController.forward();

    board = newBoard;
    score += addedScore;
    _addRandom();
    _checkGameOver();
    _buildStaticTiles();
    if (mounted) setState(() {});
  }

  void _checkGameOver() {
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] == 0) return;
        if (c + 1 < size && board[r][c] == board[r][c + 1]) return;
        if (r + 1 < size && board[r][c] == board[r + 1][c]) return;
      }
    }
    setState(() => _gameOver = true);
  }

  Color _tileColor(int val) {
    const colors = {
      0: Color(0xFFF8D7DA),
      2: Color(0xFFFFE4E8),
      4: Color(0xFFFFCDD5),
      8: Color(0xFFFF9EB5),
      16: Color(0xFFFF7096),
      32: Color(0xFFFF4D78),
      64: Color(0xFFFF1F5A),
      128: Color(0xFFE91E63),
      256: Color(0xFFC2185B),
      512: Color(0xFF9C1354),
      1024: Color(0xFF7B0D42),
      2048: Color(0xFF4A0728),
    };
    return colors[val] ?? const Color(0xFF2D0017);
  }

  Color _textColor(int val) =>
      val <= 4 ? const Color(0xFF880E4F) : Colors.white;

  double _fontSize(int val) {
    if (val >= 1024) return 18;
    if (val >= 128) return 22;
    return 26;
  }

  Offset _dragStart = Offset.zero;
  void _onPanStart(DragStartDetails d) => _dragStart = d.globalPosition;
  void _onPanEnd(DragEndDetails d) {
    final dx = d.globalPosition.dx - _dragStart.dx;
    final dy = d.globalPosition.dy - _dragStart.dy;
    if (dx.abs() < 20 && dy.abs() < 20) return;
    String dir;
    if (dx.abs() > dy.abs()) {
      dir = dx > 0 ? 'right' : 'left';
    } else {
      dir = dy > 0 ? 'down' : 'up';
    }
    HapticFeedback.lightImpact();
    _move(dir);
  }

  // اندازه هر سلول
  static const double cellSize = 76;
  static const double cellPad = 4;
  static const double boardPad = 8;

  double _pos(int idx) => boardPad + idx * (cellSize + cellPad) + cellPad;

  @override
  Widget build(BuildContext context) {
    final boardPx = boardPad * 2 + size * (cellSize + cellPad) + cellPad;

    return Scaffold(
      body: Stack(
        children: [
          // بک‌گراند صورتی با قلب
          _HeartBackground(),

          SafeArea(
            child: Column(
              children: [
                // هدر
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('2048',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black26, blurRadius: 4)])),
                      const Spacer(),
                      // امتیاز
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Column(
                          children: [
                            const Text('امتیاز',
                                style: TextStyle(fontSize: 11, color: Colors.white70)),
                            Text('$score',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // undo
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.undo, color: Colors.white),
                          onPressed: history.isEmpty ? null : _undo,
                          tooltip: 'بازگشت',
                        ),
                      ),
                      const SizedBox(width: 6),
                      // restart
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('شروع مجدد؟'),
                              content: const Text('امتیاز فعلی از دست میره.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('انصراف'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.pink),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    setState(() => _initBoard());
                                  },
                                  child: const Text('بله',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                          tooltip: 'شروع مجدد',
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'کاشی‌های یکسان رو روی هم بکش تا ۲۰۴۸ بشن! 💕',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

                // برد بازی
                Center(
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanEnd: _onPanEnd,
                    child: Container(
                      width: boardPx,
                      height: boardPx,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink[900]!.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // خانه‌های خالی
                          ...List.generate(size, (r) =>
                            List.generate(size, (c) =>
                              Positioned(
                                left: _pos(c),
                                top: _pos(r),
                                child: Container(
                                  width: cellSize,
                                  height: cellSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ).expand((e) => e),

                          // کاشی‌های متحرک
                          AnimatedBuilder(
                            animation: _moveController,
                            builder: (_, __) {
                              return Stack(
                                children: _animTiles.where((t) => !t.merged).map((t) {
                                  final progress = _moveController.value;
                                  final left = _pos(t.fromCol) + (_pos(t.toCol) - _pos(t.fromCol)) * progress;
                                  final top = _pos(t.fromRow) + (_pos(t.toRow) - _pos(t.fromRow)) * progress;
                                  return Positioned(
                                    left: left,
                                    top: top,
                                    child: _TileWidget(value: t.value, tileColor: _tileColor(t.value), textColor: _textColor(t.value), fontSize: _fontSize(t.value)),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Game Over
                if (_gameOver) ...[
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.pink.withOpacity(0.3),
                            blurRadius: 20)
                      ],
                    ),
                    child: Column(children: [
                      const Text('بازی تموم شد! 😢',
                          style: TextStyle(fontSize: 22,
                              fontWeight: FontWeight.bold, color: Colors.pink)),
                      const SizedBox(height: 8),
                      Text('امتیاز نهایی: $score',
                          style: TextStyle(fontSize: 18, color: Colors.pink[700])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _initBoard()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('دوباره بازی کن! ❤️',
                            style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// ویجت کاشی
// ============================================
class _TileWidget extends StatelessWidget {
  final int value;
  final Color tileColor;
  final Color textColor;
  final double fontSize;

  const _TileWidget({
    required this.value,
    required this.tileColor,
    required this.textColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: tileColor.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ============================================
// بک‌گراند با قلب
// ============================================
class _HeartBackground extends StatefulWidget {
  @override
  State<_HeartBackground> createState() => _HeartBackgroundState();
}

class _HeartBackgroundState extends State<_HeartBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
        painter: _HeartPainter(_ctrl.value),
        child: Container(),
        size: Size.infinite,
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final double t;
  _HeartPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // گرادیان صورتی
    final grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFFF4081),
        const Color(0xFFE91E63),
        const Color(0xFFC2185B),
        const Color(0xFF880E4F),
      ],
    );
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = grad.createShader(rect));

    // قلب‌های کوچیک
    final heartPositions = [
      [0.1, 0.1], [0.3, 0.05], [0.6, 0.08], [0.85, 0.12],
      [0.05, 0.35], [0.45, 0.25], [0.75, 0.3], [0.95, 0.4],
      [0.15, 0.6], [0.55, 0.55], [0.8, 0.65], [0.25, 0.75],
      [0.65, 0.8], [0.9, 0.85], [0.4, 0.9], [0.1, 0.88],
    ];

    for (int i = 0; i < heartPositions.length; i++) {
      final pos = heartPositions[i];
      final phase = (t + i * 0.06) % 1.0;
      final scale = 0.7 + 0.3 * sin(phase * 2 * pi);
      final opacity = 0.08 + 0.07 * sin(phase * 2 * pi);
      _drawHeart(
        canvas,
        Offset(pos[0] * size.width, pos[1] * size.height),
        14 * scale,
        Colors.white.withOpacity(opacity),
      );
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(center.dx, center.dy + r * 0.3);
    path.cubicTo(
      center.dx - r * 1.2, center.dy - r * 0.5,
      center.dx - r * 2, center.dy + r * 0.8,
      center.dx, center.dy + r * 2,
    );
    path.cubicTo(
      center.dx + r * 2, center.dy + r * 0.8,
      center.dx + r * 1.2, center.dy - r * 0.5,
      center.dx, center.dy + r * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.t != t;
}

// ============================================
// مدل‌های کمکی
// ============================================
class _TileAnim {
  final int value;
  final int fromRow, fromCol, toRow, toCol;
  final bool merged;
  _TileAnim({
    required this.value,
    required this.fromRow, required this.fromCol,
    required this.toRow, required this.toCol,
    this.merged = false,
  });
}

class _TileMove {
  final int from, to, value;
  final bool merged;
  _TileMove({required this.from, required this.to, required this.value, required this.merged});
}

class _MergeResult {
  final List<int> row;
  final List<_TileMove> moves;
  _MergeResult({required this.row, required this.moves});
}
