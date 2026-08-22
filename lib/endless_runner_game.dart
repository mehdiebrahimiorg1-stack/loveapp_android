
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: EndlessRunnerGame(),
  ));
}

class EndlessRunnerGame extends StatefulWidget {
  const EndlessRunnerGame({super.key});

  @override
  State<EndlessRunnerGame> createState() => _EndlessRunnerGameState();
}

class _EndlessRunnerGameState extends State<EndlessRunnerGame>
    with TickerProviderStateMixin {
  // ─── Game State ───
  late AnimationController _gameLoop;
  late AnimationController _laneSwitchAnim;
  late AnimationController _jumpAnim;

  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isPaused = false;

  int _score = 0;
  int _coins = 0;
  int _highScore = 0;

  double _speed = 6.0;
  double _distance = 0.0;

  // ─── Lanes ───
  static const int _laneCount = 3;
  int _currentLane = 1; // 0=left, 1=center, 2=right
  double _laneOffset = 0.0; // visual offset for smooth switching

  // ─── Jump / Duck ───
  double _jumpY = 0.0; // 0 = ground, >0 = in air
  bool _isJumping = false;
  bool _isDucking = false;

  // ─── World ───
  final List<GameObject> _objects = [];
  final List<CoinParticle> _coinParticles = [];
  double _spawnTimer = 0.0;
  final Random _rand = Random();

  // ─── Constants ───
  static const double _groundYRatio = 0.75;
  static const double _playerSize = 50.0;
  static const double _laneWidth = 100.0;
  static const double _objectSize = 50.0;
  static const double _coinSize = 30.0;
  static const double _jumpHeight = 120.0;
  static const double _jumpDuration = 0.45;

  // ─── Colors ───
  static const Color _skyTop = Color(0xFF87CEEB);
  static const Color _skyBottom = Color(0xFFE0F7FA);
  static const Color _groundColor = Color(0xFF8D6E63);
  static const Color _groundStripe = Color(0xFF6D4C41);
  static const Color _railColor = Color(0xFF90A4AE);
  static const Color _railShadow = Color(0xFF546E7A);
  static const Color _coinColor = Color(0xFFFFD700);
  static const Color _coinShine = Color(0xFFFFF59D);

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_update);

    _laneSwitchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        setState(() {});
      });

    _jumpAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: (_jumpDuration * 1000).round()),
    )..addListener(() {
        final t = _jumpAnim.value;
        // Parabolic jump: 4 * t * (1 - t)
        _jumpY = _jumpHeight * 4 * t * (1 - t);
        if (_jumpAnim.isCompleted) {
          _jumpY = 0;
          _isJumping = false;
        }
        setState(() {});
      });

    _startGame();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _isPaused = false;
      _score = 0;
      _coins = 0;
      _speed = 6.0;
      _distance = 0.0;
      _currentLane = 1;
      _laneOffset = 0.0;
      _jumpY = 0.0;
      _isJumping = false;
      _isDucking = false;
      _objects.clear();
      _coinParticles.clear();
      _spawnTimer = 0.0;
    });
    _gameLoop.forward(from: 0.0);
  }

  void _update() {
    if (!_isPlaying || _isGameOver || _isPaused) return;

    final dt = 0.016; // ~60fps

    setState(() {
      _distance += _speed * dt;
      _score = _distance ~/ 10;
      _speed = 6.0 + (_distance / 500); // gradually speed up

      // ─── Spawn objects ───
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnTimer = max(0.5, 1.5 - _distance / 5000);
        _spawnObject();
      }

      // ─── Move objects ───
      for (var obj in _objects) {
        obj.z -= _speed * dt * 60;
      }

      // ─── Remove far objects ───
      _objects.removeWhere((obj) => obj.z < -200);

      // ─── Collision ───
      _checkCollisions();

      // ─── Coin particles ───
      for (var p in _coinParticles) {
        p.life -= dt;
        p.y -= dt * 100;
      }
      _coinParticles.removeWhere((p) => p.life <= 0);
    });
  }

  void _spawnObject() {
    final lane = _rand.nextInt(_laneCount);
    final typeRoll = _rand.nextDouble();

    if (typeRoll < 0.15) {
      // Coin row (3 coins in a line)
      for (int i = 0; i < 3; i++) {
        _objects.add(GameObject(
          lane: lane,
          z: 800.0 + i * 80,
          type: ObjectType.coin,
        ));
      }
    } else if (typeRoll < 0.25) {
      // Coin spread across lanes
      for (int l = 0; l < _laneCount; l++) {
        _objects.add(GameObject(
          lane: l,
          z: 800.0,
          type: ObjectType.coin,
        ));
      }
    } else if (typeRoll < 0.45) {
      // Obstacle
      _objects.add(GameObject(
        lane: lane,
        z: 800.0,
        type: ObjectType.obstacle,
      ));
    } else if (typeRoll < 0.55) {
      // Train (wide obstacle)
      _objects.add(GameObject(
        lane: lane,
        z: 800.0,
        type: ObjectType.train,
      ));
    } else if (typeRoll < 0.65) {
      // Barrier that needs duck
      _objects.add(GameObject(
        lane: lane,
        z: 800.0,
        type: ObjectType.barrier,
      ));
    } else {
      // Mixed: coin + obstacle
      final coinLane = (lane + 1) % _laneCount;
      _objects.add(GameObject(
        lane: lane,
        z: 800.0,
        type: ObjectType.obstacle,
      ));
      _objects.add(GameObject(
        lane: coinLane,
        z: 800.0,
        type: ObjectType.coin,
      ));
    }
  }

  void _checkCollisions() {
    final playerZ = 100.0;
    final playerLane = _currentLane;

    for (var obj in _objects) {
      if (obj.hit) continue;

      // Check Z proximity
      if ((obj.z - playerZ).abs() < 40) {
        // Check lane
        if (obj.lane == playerLane) {
          if (obj.type == ObjectType.coin) {
            obj.hit = true;
            _coins++;
            _coinParticles.add(CoinParticle(
              x: _getLaneX(obj.lane),
              y: _getScreenY(obj.z) - 30,
              life: 0.8,
            ));
          } else if (obj.type == ObjectType.obstacle) {
            if (_jumpY < 20) {
              _gameOver();
            }
          } else if (obj.type == ObjectType.train) {
            _gameOver();
          } else if (obj.type == ObjectType.barrier) {
            if (!_isDucking) {
              _gameOver();
            }
          }
        }
      }
    }

    _objects.removeWhere((obj) => obj.hit);
  }

  void _gameOver() {
    _isGameOver = true;
    _isPlaying = false;
    _gameLoop.stop();
    if (_score > _highScore) {
      _highScore = _score;
    }
  }

  // ─── Controls ───
  void _moveLeft() {
    if (_isGameOver || _isPaused) return;
    if (_currentLane > 0) {
      _currentLane--;
      _laneSwitchAnim.forward(from: 0.0);
    }
  }

  void _moveRight() {
    if (_isGameOver || _isPaused) return;
    if (_currentLane < _laneCount - 1) {
      _currentLane++;
      _laneSwitchAnim.forward(from: 0.0);
    }
  }

  void _jump() {
    if (_isGameOver || _isPaused || _isJumping) return;
    _isJumping = true;
    _jumpAnim.forward(from: 0.0);
  }

  void _duck(bool down) {
    if (_isGameOver || _isPaused) return;
    setState(() {
      _isDucking = down;
    });
  }

  // ─── Helpers ───
  double _getLaneX(int lane) {
    final centerX = MediaQuery.of(context).size.width / 2;
    return centerX + (lane - 1) * _laneWidth;
  }

  double _getScreenY(double z) {
    final height = MediaQuery.of(context).size.height;
    final groundY = height * _groundYRatio;
    // Perspective projection
    final fov = 300.0;
    return groundY - (fov * 100 / (z + 100)) + 80;
  }

  double _getScale(double z) {
    return 0.3 + (700 / (z + 100)) * 0.7;
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _moveLeft();
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) _moveRight();
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) _jump();
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) _duck(true);
        }
        if (event is RawKeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) _duck(false);
        }
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) _moveLeft();
          if (details.primaryVelocity! > 300) _moveRight();
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) _jump();
        },
        onTapDown: (_) => _duck(true),
        onTapUp: (_) => _duck(false),
        onTapCancel: () => _duck(false),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ─── Game Canvas ───
              CustomPaint(
                size: Size.infinite,
                painter: _GamePainter(
                  laneCount: _laneCount,
                  laneWidth: _laneWidth,
                  currentLane: _currentLane,
                  laneOffset: _laneSwitchAnim.value,
                  jumpY: _jumpY,
                  isDucking: _isDucking,
                  objects: _objects,
                  coinParticles: _coinParticles,
                  distance: _distance,
                  getLaneX: _getLaneX,
                  getScreenY: _getScreenY,
                  getScale: _getScale,
                ),
              ),

              // ─── HUD ───
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHudCard('SCORE', '$_score', Colors.blue),
                          _buildHudCard('COINS', '$_coins', _coinColor),
                          _buildHudCard('HIGH', '$_highScore', Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SPEED: ${_speed.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Pause Button ───
              if (_isPlaying && !_isGameOver)
                Positioned(
                  top: 16,
                  right: 16,
                  child: SafeArea(
                    child: IconButton(
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPaused = !_isPaused;
                          if (_isPaused) {
                            _gameLoop.stop();
                          } else {
                            _gameLoop.forward();
                          }
                        });
                      },
                    ),
                  ),
                ),

              // ─── Game Over Overlay ───
              if (_isGameOver)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'GAME OVER',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Score: $_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          'Coins: $_coins',
                          style: const TextStyle(
                            color: _coinColor,
                            fontSize: 24,
                          ),
                        ),
                        if (_score >= _highScore && _score > 0)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'NEW HIGH SCORE!',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: _startGame,
                          icon: const Icon(Icons.replay, size: 28),
                          label: const Text(
                            'PLAY AGAIN',
                            style: TextStyle(fontSize: 20),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ─── Pause Overlay ───
              if (_isPaused)
                Container(
                  color: Colors.black60,
                  child: const Center(
                    child: Text(
                      'PAUSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // ─── Mobile Controls Hint ───
              if (_isPlaying && !_isGameOver && !_isPaused)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'SWIPE: Left/Right/Up  |  HOLD: Duck',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHudCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    _laneSwitchAnim.dispose();
    _jumpAnim.dispose();
    super.dispose();
  }
}

// ─── Models ───

enum ObjectType { obstacle, coin, train, barrier }

class GameObject {
  int lane;
  double z;
  ObjectType type;
  bool hit = false;

  GameObject({
    required this.lane,
    required this.z,
    required this.type,
  });
}

class CoinParticle {
  double x;
  double y;
  double life;

  CoinParticle({
    required this.x,
    required this.y,
    required this.life,
  });
}

// ─── Painter ───

class _GamePainter extends CustomPainter {
  final int laneCount;
  final double laneWidth;
  final int currentLane;
  final double laneOffset;
  final double jumpY;
  final bool isDucking;
  final List<GameObject> objects;
  final List<CoinParticle> coinParticles;
  final double distance;
  final double Function(int) getLaneX;
  final double Function(double) getScreenY;
  final double Function(double) getScale;

  _GamePainter({
    required this.laneCount,
    required this.laneWidth,
    required this.currentLane,
    required this.laneOffset,
    required this.jumpY,
    required this.isDucking,
    required this.objects,
    required this.coinParticles,
    required this.distance,
    required this.getLaneX,
    required this.getScreenY,
    required this.getScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawGround(canvas, size);
    _drawRails(canvas, size);
    _drawObjects(canvas);
    _drawPlayer(canvas, size);
    _drawCoinParticles(canvas);
  }

  void _drawSky(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          EndlessRunnerGame._skyTop,
          EndlessRunnerGame._skyBottom,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.75), paint);

    // Draw some clouds
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.4);
    for (int i = 0; i < 5; i++) {
      final x = (i * 200.0 + distance * 0.1) % (size.width + 200) - 100;
      final y = 50 + i * 30.0;
      _drawCloud(canvas, x, y, 40 + i * 10, cloudPaint);
    }
  }

  void _drawCloud(Canvas canvas, double x, double y, double size, Paint paint) {
    canvas.drawCircle(Offset(x, y), size * 0.5, paint);
    canvas.drawCircle(Offset(x + size * 0.3, y - size * 0.1), size * 0.4, paint);
    canvas.drawCircle(Offset(x - size * 0.3, y + size * 0.05), size * 0.35, paint);
  }

  void _drawGround(Canvas canvas, Size size) {
    final groundY = size.height * EndlessRunnerGame._groundYRatio;

    // Main ground
    final groundPaint = Paint()..color = EndlessRunnerGame._groundColor;
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      groundPaint,
    );

    // Moving stripes for speed effect
    final stripePaint = Paint()..color = EndlessRunnerGame._groundStripe;
    final stripeWidth = 40.0;
    final offset = -(distance * 2) % (stripeWidth * 2);

    for (double x = offset - stripeWidth * 2;
        x < size.width + stripeWidth * 2;
        x += stripeWidth * 2) {
      // Perspective trapezoid stripes
      final path = Path();
      path.moveTo(x, groundY);
      path.lineTo(x + stripeWidth * 0.3, groundY);
      path.lineTo(x + stripeWidth, size.height);
      path.lineTo(x + stripeWidth * 0.7, size.height);
      path.close();
      canvas.drawPath(path, stripePaint);
    }

    // Horizon line
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 2,
    );
  }

  void _drawRails(Canvas canvas, Size size) {
    final groundY = size.height * EndlessRunnerGame._groundYRatio;
    final centerX = size.width / 2;

    for (int i = 0; i < laneCount + 1; i++) {
      final x = centerX + (i - laneCount / 2) * laneWidth;

      // Rail shadow
      canvas.drawLine(
        Offset(x + 2, groundY),
        Offset(x + 2, size.height),
        Paint()
          ..color = EndlessRunnerGame._railShadow
          ..strokeWidth = 6,
      );

      // Rail
      canvas.drawLine(
        Offset(x, groundY),
        Offset(x, size.height),
        Paint()
          ..color = EndlessRunnerGame._railColor
          ..strokeWidth = 4,
      );

      // Rail shine
      canvas.drawLine(
        Offset(x - 1, groundY),
        Offset(x - 1, size.height),
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..strokeWidth = 1,
      );
    }

    // Sleepers (cross ties)
    final sleeperPaint = Paint()..color = Colors.brown.shade700;
    final sleeperSpacing = 60.0;
    final sleeperOffset = -(distance * 3) % sleeperSpacing;

    for (double y = groundY + sleeperOffset;
        y < size.height;
        y += sleeperSpacing) {
      final widthAtY = laneWidth * laneCount;
      final leftX = centerX - widthAtY / 2;
      canvas.drawRect(
        Rect.fromLTWH(leftX - 5, y, widthAtY + 10, 8),
        sleeperPaint,
      );
    }
  }

  void _drawObjects(Canvas canvas) {
    // Sort by Z (far to near)
    final sorted = List<GameObject>.from(objects)
      ..sort((a, b) => b.z.compareTo(a.z));

    for (var obj in sorted) {
      final x = getLaneX(obj.lane);
      final y = getScreenY(obj.z);
      final scale = getScale(obj.z);

      if (obj.type == ObjectType.coin) {
        _drawCoin(canvas, x, y, scale);
      } else if (obj.type == ObjectType.obstacle) {
        _drawObstacle(canvas, x, y, scale);
      } else if (obj.type == ObjectType.train) {
        _drawTrain(canvas, x, y, scale);
      } else if (obj.type == ObjectType.barrier) {
        _drawBarrier(canvas, x, y, scale);
      }
    }
  }

  void _drawCoin(Canvas canvas, double x, double y, double scale) {
    final size = EndlessRunnerGame._coinSize * scale;
    final paint = Paint()
      ..color = EndlessRunnerGame._coinColor
      ..style = PaintingStyle.fill;

    // Coin body
    canvas.drawCircle(Offset(x, y - size / 2), size / 2, paint);

    // Shine
    canvas.drawCircle(
      Offset(x - size * 0.15, y - size * 0.6),
      size * 0.15,
      Paint()..color = EndlessRunnerGame._coinShine,
    );

    // Inner ring
    canvas.drawCircle(
      Offset(x, y - size / 2),
      size * 0.3,
      Paint()
        ..color = Colors.orange.shade700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale,
    );

    // "$" symbol
    final textPainter = TextPainter(
      text: TextSpan(
        text: '\$',
        style: TextStyle(
          color: Colors.orange.shade800,
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - size / 2 - textPainter.height / 2),
    );
  }

  void _drawObstacle(Canvas canvas, double x, double y, double scale) {
    final size = EndlessRunnerGame._objectSize * scale;
    final rect = Rect.fromCenter(
      center: Offset(x, y - size / 2),
      width: size,
      height: size,
    );

    // Box body
    canvas.drawRect(
      rect,
      Paint()..color = Colors.red.shade700,
    );

    // Box border
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.red.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale,
    );

    // Warning stripes
    final stripePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 3 * scale;
    for (int i = -1; i < 2; i++) {
      canvas.drawLine(
        Offset(x - size / 2 + 5 * scale, y - size + i * size * 0.3),
        Offset(x + size / 2 - 5 * scale, y - i * size * 0.3),
        stripePaint,
      );
    }
  }

  void _drawTrain(Canvas canvas, double x, double y, double scale) {
    final w = EndlessRunnerGame._objectSize * scale * 1.8;
    final h = EndlessRunnerGame._objectSize * scale * 1.2;
    final rect = Rect.fromCenter(
      center: Offset(x, y - h / 2),
      width: w,
      height: h,
    );

    // Train body
    canvas.drawRect(
      rect,
      Paint()..color = Colors.blue.shade800,
    );

    // Windows
    final windowPaint = Paint()..color = Colors.cyan.shade200;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x - w * 0.2, y - h * 0.6),
        width: w * 0.25,
        height: h * 0.25,
      ),
      windowPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x + w * 0.2, y - h * 0.6),
        width: w * 0.25,
        height: h * 0.25,
      ),
      windowPaint,
    );

    // Stripe
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, y - h * 0.35),
        width: w,
        height: h * 0.08,
      ),
      Paint()..color = Colors.yellow,
    );
  }

  void _drawBarrier(Canvas canvas, double x, double y, double scale) {
    final w = EndlessRunnerGame._objectSize * scale * 1.2;
    final h = EndlessRunnerGame._objectSize * scale * 0.4;
    final rect = Rect.fromCenter(
      center: Offset(x, y - h / 2 - 5 * scale),
      width: w,
      height: h,
    );

    // Barrier bar
    canvas.drawRect(
      rect,
      Paint()..color = Colors.orange.shade800,
    );

    // Supports
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x - w * 0.35, y - h / 2),
        width: 6 * scale,
        height: 20 * scale,
      ),
      Paint()..color = Colors.grey.shade700,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x + w * 0.35, y - h / 2),
        width: 6 * scale,
        height: 20 * scale,
      ),
      Paint()..color = Colors.grey.shade700,
    );

    // Warning sign
    canvas.drawCircle(
      Offset(x, y - h - 15 * scale),
      12 * scale,
      Paint()..color = Colors.yellow,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16 * scale,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - h - 15 * scale - textPainter.height / 2),
    );
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final groundY = size.height * EndlessRunnerGame._groundYRatio;
    final x = getLaneX(currentLane);
    final y = groundY - 60 - jumpY;
    final playerSize = EndlessRunnerGame._playerSize;

    // Shadow
    if (jumpY > 5) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, groundY - 5),
          width: playerSize * (1 - jumpY / 200),
          height: 10,
        ),
        Paint()..color = Colors.black.withOpacity(0.2),
      );
    }

    final bodyHeight = isDucking ? playerSize * 0.6 : playerSize;
    final bodyY = y - bodyHeight / 2;

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, bodyY),
          width: playerSize * 0.7,
          height: bodyHeight,
        ),
        const Radius.circular(12),
      ),
      Paint()..color = Colors.orange.shade400,
    );

    // Head
    final headY = bodyY - bodyHeight / 2 - playerSize * 0.25;
    canvas.drawCircle(
      Offset(x, headY),
      playerSize * 0.3,
      Paint()..color = Colors.amber.shade100,
    );

    // Hoodie / hair
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(x, headY),
        width: playerSize * 0.65,
        height: playerSize * 0.5,
      ),
      pi,
      pi,
      false,
      Paint()..color = Colors.orange.shade500,
    );

    // Eyes
    final eyePaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(x - 6, headY + 2), 3, eyePaint);
    canvas.drawCircle(Offset(x + 6, headY + 2), 3, eyePaint);

    // Backpack
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x - playerSize * 0.45, bodyY),
          width: playerSize * 0.25,
          height: bodyHeight * 0.7,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.green.shade600,
    );

    // Legs (animated)
    final legSwing = isDucking ? 0.0 : sin(distance * 0.3) * 10;
    final legPaint = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final legY = bodyY + bodyHeight / 2;
    canvas.drawLine(
      Offset(x - 8, legY),
      Offset(x - 8 + legSwing, legY + 20),
      legPaint,
    );
    canvas.drawLine(
      Offset(x + 8, legY),
      Offset(x + 8 - legSwing, legY + 20),
      legPaint,
    );

    // Shoes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x - 8 + legSwing, legY + 22),
          width: 14,
          height: 8,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.red.shade700,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + 8 - legSwing, legY + 22),
          width: 14,
          height: 8,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.red.shade700,
    );
  }

  void _drawCoinParticles(Canvas canvas) {
    for (var p in coinParticles) {
      final alpha = (p.life * 255).toInt().clamp(0, 255);
      canvas.drawCircle(
        Offset(p.x, p.y),
        8,
        Paint()..color = EndlessRunnerGame._coinColor.withAlpha(alpha),
      );
      canvas.drawText(
        TextSpan(
          text: '+1',
          style: TextStyle(
            color: Colors.white.withAlpha(alpha),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Offset(p.x + 10, p.y - 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Helper extension for drawing text on canvas
extension CanvasText on Canvas {
  void drawText(TextSpan textSpan, Offset offset) {
    final painter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(this, offset);
  }
}
