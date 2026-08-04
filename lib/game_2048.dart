import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// ============================================
// بازی 2048
// ============================================
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
  List<List<List<int>>> history = []; // تاریخچه برای undo
  bool _gameOver = false;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _initBoard();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _initBoard() {
    board = List.generate(size, (_) => List.filled(size, 0));
    score = 0;
    history = [];
    _gameOver = false;
    _addRandom();
    _addRandom();
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
    });
  }

  void _restart() {
    setState(() => _initBoard());
  }

  // حرکت یه ردیف به چپ
  List<int> _mergeLeft(List<int> row) {
    List<int> filtered = row.where((v) => v != 0).toList();
    for (int i = 0; i < filtered.length - 1; i++) {
      if (filtered[i] == filtered[i + 1]) {
        filtered[i] *= 2;
        score += filtered[i];
        filtered.removeAt(i + 1);
      }
    }
    while (filtered.length < size) filtered.add(0);
    return filtered;
  }

  bool _move(String dir) {
    _saveHistory();
    final prev = _copyBoard();
    bool moved = false;

    if (dir == 'left' || dir == 'right') {
      for (int r = 0; r < size; r++) {
        List<int> row = List.from(board[r]);
        if (dir == 'right') row = row.reversed.toList();
        row = _mergeLeft(row);
        if (dir == 'right') row = row.reversed.toList();
        board[r] = row;
      }
    } else {
      for (int c = 0; c < size; c++) {
        List<int> col = List.generate(size, (r) => board[r][c]);
        if (dir == 'down') col = col.reversed.toList();
        col = _mergeLeft(col);
        if (dir == 'down') col = col.reversed.toList();
        for (int r = 0; r < size; r++) board[r][c] = col[r];
      }
    }

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (board[r][c] != prev[r][c]) { moved = true; break; }
      }
      if (moved) break;
    }

    if (moved) {
      _addRandom();
      _checkGameOver();
    } else {
      history.removeLast();
    }

    return moved;
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
      0: Color(0xFFEDE0D4),
      2: Color(0xFFEEE4DA),
      4: Color(0xFFEDE0C8),
      8: Color(0xFFF2B179),
      16: Color(0xFFF59563),
      32: Color(0xFFF67C5F),
      64: Color(0xFFF65E3B),
      128: Color(0xFFEDCF72),
      256: Color(0xFFEDCC61),
      512: Color(0xFFEDC850),
      1024: Color(0xFFEDC53F),
      2048: Color(0xFFEDC22E),
    };
    return colors[val] ?? const Color(0xFF3C3A32);
  }

  Color _textColor(int val) =>
      val <= 4 ? const Color(0xFF776E65) : Colors.white;

  double _fontSize(int val) {
    if (val >= 1024) return 20;
    if (val >= 128) return 24;
    return 28;
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
    setState(() => _move(dir));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBBADA0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text('2048',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const Spacer(),
            // امتیاز
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8F7A66),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('امتیاز',
                      style: TextStyle(fontSize: 10, color: Color(0xFFEEE4DA))),
                  Text('$score',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // undo
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'بازگشت',
            onPressed: history.isEmpty ? null : _undo,
          ),
          // restart
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'شروع مجدد',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
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
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'کاشی‌های یکسان رو روی هم بکش تا ۲۰۴۸ بشن!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF776E65), fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          // برد بازی
          Expanded(
            child: Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onPanStart: _onPanStart,
                    onPanEnd: _onPanEnd,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBBADA0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(size, (r) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(size, (c) {
                            final val = board[r][c];
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 76,
                              height: 76,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _tileColor(val),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: val > 0 ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : [],
                              ),
                              child: Center(
                                child: val > 0
                                    ? Text(
                                        '$val',
                                        style: TextStyle(
                                          fontSize: _fontSize(val),
                                          fontWeight: FontWeight.bold,
                                          color: _textColor(val),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          }),
                        )),
                      ),
                    ),
                  ),
                  // Game Over overlay
                  if (_gameOver)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'بازی تموم شد! 😢',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'امتیاز: $score',
                              style: const TextStyle(
                                  fontSize: 20, color: Colors.white70),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => setState(() => _initBoard()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF65E3B),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('دوباره بازی کن!',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
