import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// Enum for Difficulty Levels
enum Difficulty { slow, medium, fast }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bucket Ball Game',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        fontFamily: 'Arial',
        dialogBackgroundColor: Colors.blue[50],
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
          buttonColor: Colors.lightBlueAccent,
        ),
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Data Model for a Ball ---
class Ball {
  Offset position;
  Color color;
  double speed;
  final double radius;
  final String id;

  Ball({
    required this.position,
    required this.color,
    required this.speed,
    this.radius = 15.0,
  }) : id = UniqueKey().toString();
}

// --- Game Screen Widget ---
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Ball> _balls = [];
  double _bucketX = 0.0;
  final double _bucketWidth = 100.0;
  final double _bucketHeight = 80.0;
  final double _bucketRimHeight = 20.0;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  Timer? _gameTimer;
  final Random _random = Random();
  bool _gameOver = false;
  bool _isGamePaused = false;
  Size _screenSize = Size.zero;
  Difficulty _currentDifficulty = Difficulty.medium;

  final double _ballRadius = 15.0;
  final List<Color> _ballColors = [Colors.redAccent, Colors.yellowAccent.shade700, Colors.cyanAccent];
  final double _desiredBottomPadding = 10.0;

  bool _gameInitialized = false;
  bool _isGameStarted = false; // New state to track if game has started
  int _ballsToSpawnSimultaneously = 1;
  double _currentBaseSpeedMultiplier = 1.0;

  final int _scoreForSpeedIncrease = 500;
  final int _scoreForExtraBall = 1000;
  int _nextSpeedIncreaseThreshold = 500;
  int _nextExtraBallThreshold = 1000;

  final Color _darkNavyBlueStart = const Color(0xFF00003B);
  final Color _darkNavyBlueEnd = const Color(0xFF000055);

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _initializeGameOnce() {
    if (!_gameInitialized && _screenSize.width > 0 && _screenSize.height > 0) {
      _bucketX = _screenSize.width / 2;
      _gameInitialized = true;
      // Game is initialized, but not started yet.
      // setState to allow UI to update (e.g., show Start Button).
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _resetAndStartGame() {
    if (_screenSize == Size.zero && !_gameInitialized) {
      // Should not happen if UI forces start button only after init
      return;
    }

    _isGameStarted = true; // Mark game as started
    _balls.clear();
    _score = 0;
    _lives = 3;
    _gameOver = false;
    _isGamePaused = false;
    _ballsToSpawnSimultaneously = 1;
    _currentBaseSpeedMultiplier = 1.0;
    _nextSpeedIncreaseThreshold = _scoreForSpeedIncrease;
    _nextExtraBallThreshold = _scoreForExtraBall;

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 30), _gameLoop);
    _spawnNewBallsIfNeeded(); // Spawn initial balls

    if (mounted) { // Update UI to reflect new game state
      setState(() {});
    }
  }

  void _pauseGame() {
    if (!_isGameStarted || _gameOver) return; // Can only pause an active, ongoing game
    if (_gameTimer != null && _gameTimer!.isActive) {
      _gameTimer!.cancel();
      _isGamePaused = true;
      if (mounted) setState(() {});
    }
  }

  void _resumeGame() {
    if (!_isGameStarted || _gameOver || !_isGamePaused) return; // Can only resume a paused, active game

    _gameTimer?.cancel(); // Ensure no multiple timers
    _gameTimer = Timer.periodic(const Duration(milliseconds: 30), _gameLoop);
    _isGamePaused = false;
    if (mounted) setState(() {});
  }

  double _getBallSpeedBasedOnDifficultyAndProgression() {
    double baseSpeed;
    double variance;
    switch (_currentDifficulty) {
      case Difficulty.slow: baseSpeed = 1.8; variance = 0.4; break;
      case Difficulty.medium: baseSpeed = 2.8; variance = 0.8; break;
      case Difficulty.fast: baseSpeed = 4.2; variance = 1.2; break;
    }
    return (baseSpeed + _random.nextDouble() * variance) * _currentBaseSpeedMultiplier;
  }

  void _spawnNewBallsIfNeeded() {
    if (_gameOver || !_gameInitialized || _isGamePaused || !_isGameStarted) return;
    while (_balls.length < _ballsToSpawnSimultaneously) {
      double randomX = _random.nextDouble() * (_screenSize.width - _ballRadius * 2) + _ballRadius;
      Color randomColor = _ballColors[_random.nextInt(_ballColors.length)];
      double ballSpeed = _getBallSpeedBasedOnDifficultyAndProgression();
      _balls.add(Ball(
        position: Offset(randomX, -_ballRadius),
        color: randomColor,
        speed: ballSpeed,
        radius: _ballRadius,
      ));
    }
  }

  void _updateGameProgression() {
    if (_score >= _nextSpeedIncreaseThreshold) {
      _currentBaseSpeedMultiplier += 0.15;
      _nextSpeedIncreaseThreshold += _scoreForSpeedIncrease;
    }
    if (_score >= _nextExtraBallThreshold) {
      if(_ballsToSpawnSimultaneously < 3) _ballsToSpawnSimultaneously++;
      _nextExtraBallThreshold += _scoreForExtraBall;
    }
  }

  void _handleBallMiss() {
    if (!_gameOver) {
      setState(() {
        _lives--;
        if (_lives <= 0) {
          _gameOver = true;
          _gameTimer?.cancel(); // Cancel timer immediately on game over
          if (_score > _highScore) _highScore = _score;
        }
      });
    }
  }

  void _gameLoop(Timer timer) {
    if (!mounted || _screenSize == Size.zero || _isGamePaused || !_isGameStarted || _gameOver) {
      if (_gameOver && _gameTimer?.isActive == true) {
        _gameTimer!.cancel(); // Ensure timer is cancelled if game over state is reached
      }
      return;
    }

    setState(() {
      // This setState is for continuous updates (ball movement)
      // _gameOver check is mostly handled by the guard above or _handleBallMiss

      List<Ball> ballsToRemove = [];
      double bucketCatchAreaTopY = (_screenSize.height - _bucketHeight - _desiredBottomPadding)
          .clamp(0.0, _screenSize.height - _bucketHeight);

      for (var ball in _balls) {
        ball.position = Offset(ball.position.dx, ball.position.dy + ball.speed);
        double bucketLeft = _bucketX - _bucketWidth / 2;
        double bucketRight = _bucketX + _bucketWidth / 2;

        if (ball.position.dx >= bucketLeft &&
            ball.position.dx <= bucketRight &&
            ball.position.dy + ball.radius >= bucketCatchAreaTopY &&
            ball.position.dy - ball.radius <= bucketCatchAreaTopY + _bucketRimHeight) {
          ballsToRemove.add(ball);
          _score += 100;
          _updateGameProgression();
        } else if (ball.position.dy - ball.radius > _screenSize.height) {
          ballsToRemove.add(ball);
          _handleBallMiss();
        }
      }

      bool ballWasRemoved = ballsToRemove.isNotEmpty;
      _balls.removeWhere((ball) => ballsToRemove.any((btr) => btr.id == ball.id));

      if (ballWasRemoved && !_gameOver) _spawnNewBallsIfNeeded();
      if (_balls.isEmpty && !_gameOver && _isGameStarted) _spawnNewBallsIfNeeded(); // Ensure we spawn if game is on and no balls
    });
  }

  void _moveBucket(DragUpdateDetails details) {
    if (!_isGameStarted || _gameOver || _screenSize.width == 0 || _isGamePaused) return;
    setState(() {
      double newProposedBucketX = _bucketX + details.delta.dx;
      double proposedLeftEdge = newProposedBucketX - (_bucketWidth / 2);
      double maxLeftEdge = _screenSize.width - _bucketWidth;
      double clampedLeftEdge = proposedLeftEdge.clamp(0.0, max(0.0, maxLeftEdge));
      _bucketX = clampedLeftEdge + (_bucketWidth / 2);
    });
  }

  void _showSettingsDialog() {
    // Pause game if it's running, otherwise, it does nothing.
    _pauseGame();
    Difficulty tempDifficulty = _currentDifficulty;

    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with dialog
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.blue[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              title: Row(
                children: [
                  Icon(Icons.settings_applications, color: Theme.of(context).primaryColorDark),
                  const SizedBox(width: 10),
                  const Text('Game Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Difficulty Level:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                    const SizedBox(height: 8),
                    RadioListTile<Difficulty>(
                      title: const Text('Slow', style: TextStyle(color: Colors.black54)),
                      value: Difficulty.slow, groupValue: tempDifficulty,
                      onChanged: (Difficulty? value) { if (value != null) setDialogState(() => tempDifficulty = value); },
                      activeColor: Theme.of(context).primaryColorDark,
                    ),
                    RadioListTile<Difficulty>(
                      title: const Text('Medium', style: TextStyle(color: Colors.black54)),
                      value: Difficulty.medium, groupValue: tempDifficulty,
                      onChanged: (Difficulty? value) { if (value != null) setDialogState(() => tempDifficulty = value); },
                      activeColor: Theme.of(context).primaryColorDark,
                    ),
                    RadioListTile<Difficulty>(
                      title: const Text('Fast', style: TextStyle(color: Colors.black54)),
                      value: Difficulty.fast, groupValue: tempDifficulty,
                      onChanged: (Difficulty? value) { if (value != null) setDialogState(() => tempDifficulty = value); },
                      activeColor: Theme.of(context).primaryColorDark,
                    ),
                    const Divider(height: 20, thickness: 1, color: Colors.black26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Highest Score:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                        Text('$_highScore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark)),
                      ],
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceAround,
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Only resume if the game was actually started and paused.
                    if (_isGameStarted && _isGamePaused) {
                      _resumeGame();
                    }
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text('Apply & Restart', style: TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: () {
                    if (mounted) {
                      setState(() { _currentDifficulty = tempDifficulty; });
                    }
                    Navigator.of(context).pop();
                    _resetAndStartGame(); // This will set _isGameStarted = true and start
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLivesDisplay() {
    const double heartIconSize = 30.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Icon(
            index < _lives ? Icons.favorite : Icons.favorite_border,
            color: Colors.pinkAccent,
            size: heartIconSize,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double appBarIconSize = 40.0;

    final appBarWidget = AppBar(
      backgroundColor: Colors.lightBlue[400],
      elevation: 0,
      leadingWidth: appBarIconSize + 16 + 80,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/coin.png',
                  width: appBarIconSize,
                  height: appBarIconSize,
                  errorBuilder: (c,e,s) => Icon(Icons.star_rounded, color: Colors.yellowAccent, size: appBarIconSize)
              ),
              const SizedBox(width: 10),
              Text('$_score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
      ),
      title: _buildLivesDisplay(),
      centerTitle: true,
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            iconSize: appBarIconSize,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Image.asset('assets/settings.png',
                width: appBarIconSize,
                height: appBarIconSize,
                errorBuilder: (c,e,s) => Icon(Icons.settings_outlined, color: Colors.white, size: appBarIconSize)
            ),
            onPressed: _showSettingsDialog,
          ),
        )
      ],
    );

    return Scaffold(
      appBar: appBarWidget,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final newScreenSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (_screenSize != newScreenSize) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _screenSize = newScreenSize;
                  if (!_gameInitialized || (_bucketX == 0.0 && _screenSize.width > 0)) {
                    _initializeGameOnce();
                  } else if (_screenSize.width > 0) {
                    _bucketX = _bucketX.clamp(_bucketWidth / 2, _screenSize.width - _bucketWidth / 2);
                  }
                });
              }
            });
          }

          // Loading screen if not initialized
          if (!_gameInitialized || _screenSize == Size.zero) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_darkNavyBlueStart, _darkNavyBlueEnd],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }

          double bucketVisualTopY = (_screenSize.height - _bucketHeight - _desiredBottomPadding)
              .clamp(0.0, _screenSize.height - _bucketHeight);

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_darkNavyBlueStart, _darkNavyBlueEnd],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: GestureDetector(
              onHorizontalDragUpdate: (!_isGameStarted || _isGamePaused || _gameOver) ? null : _moveBucket,
              onTap: (_isGamePaused && _isGameStarted && !_gameOver) ? _resumeGame : null,
              child: Stack(
                children: [
                  // Game elements (always rendered, but may be covered by overlays)
                  if (_isGameStarted) // Only show balls and bucket if game has started
                    ..._balls.map((ball) => Positioned(
                      left: ball.position.dx - ball.radius,
                      top: ball.position.dy - ball.radius,
                      child: Container(
                        width: ball.radius * 2,
                        height: ball.radius * 2,
                        decoration: BoxDecoration(
                            color: ball.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(2,2)
                              )
                            ]
                        ),
                      ),
                    )),
                  if (_isGameStarted) // Only show bucket if game has started
                    Positioned(
                      left: _bucketX - _bucketWidth / 2,
                      top: bucketVisualTopY,
                      child: CustomPaint(
                        size: Size(_bucketWidth, _bucketHeight),
                        painter: BucketPainter(rimColor: Colors.pinkAccent.shade100, bodyColor: Colors.purple.shade300),
                      ),
                    ),

                  // --- Overlays ---

                  // Start Game Button Overlay
                  if (_gameInitialized && !_isGameStarted)
                    Container(
                      color: Colors.black.withOpacity(0.65),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Bucket Ball',
                              style: TextStyle(fontSize: 48, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5, shadows: [
                                Shadow(blurRadius: 10.0, color: Colors.black.withOpacity(0.5), offset: Offset(2,2))
                              ]),
                            ),
                            const SizedBox(height: 40),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent[400],
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                  textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              onPressed: _resetAndStartGame, // This will set _isGameStarted = true
                              child: const Text('Start Game', style: TextStyle(color: Colors.black87)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Game Over Overlay
                  if (_gameOver) // This implies _isGameStarted was true
                    Container(
                      color: Colors.black.withOpacity(0.75),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'GAME OVER',
                              style: TextStyle(fontSize: 48, color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Your Score: $_score',
                              style: const TextStyle(fontSize: 24, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'High Score: $_highScore',
                              style: const TextStyle(fontSize: 20, color: Colors.amberAccent),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent[400],
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  textStyle: const TextStyle(fontSize: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              onPressed: _resetAndStartGame,
                              child: const Text('Play Again', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Paused Overlay
                  if (_isGamePaused && _isGameStarted && !_gameOver)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: Text(
                          'PAUSED',
                          style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Custom Painter for the Bucket ---
class BucketPainter extends CustomPainter {
  final Color rimColor;
  final Color bodyColor;
  final Size? size; // size parameter is not strictly needed here as actualSize is provided

  BucketPainter({required this.rimColor, required this.bodyColor, this.size});

  @override
  void paint(Canvas canvas, Size actualSize) {
    final rimPaint = Paint()..color = rimColor;
    final bodyPaint = Paint()..color = bodyColor;
    final darkBodyPaint = Paint()..color = Color.lerp(bodyColor, Colors.black, 0.2)!; // Inner shadow/darker part

    double w = actualSize.width;
    double h = actualSize.height;
    double rimHeight = h * 0.2; // e.g., 20% of height for the rim
    double bodyTopWidth = w; // Bucket opening width
    double bodyBottomWidth = w * 0.8; // Bucket base width (slightly tapered)

    // Rim
    canvas.drawRRect(
        RRect.fromLTRBAndCorners(0, 0, w, rimHeight,
            topLeft: const Radius.circular(8), topRight: const Radius.circular(8)),
        rimPaint);

    // Body
    Path bodyPath = Path();
    bodyPath.moveTo((w - bodyTopWidth) / 2, rimHeight); // Top-left of body
    bodyPath.lineTo((w - bodyTopWidth) / 2 + bodyTopWidth, rimHeight); // Top-right of body
    bodyPath.lineTo((w - bodyBottomWidth) / 2 + bodyBottomWidth, h); // Bottom-right of body
    bodyPath.lineTo((w - bodyBottomWidth) / 2, h); // Bottom-left of body
    bodyPath.close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Simple highlight on the body
    Path highlightPath = Path();
    highlightPath.moveTo(w * 0.25, rimHeight + h * 0.1);
    highlightPath.quadraticBezierTo(w * 0.5, rimHeight + h * 0.3, w * 0.35, rimHeight + h * 0.65);
    highlightPath.quadraticBezierTo(w * 0.1, rimHeight + h * 0.8, w * 0.25, rimHeight + h * 0.1);
    highlightPath.close();
    canvas.drawPath(highlightPath, Paint()..color = Colors.white.withOpacity(0.3));


    // Darker bottom part for a bit of depth (optional)
    Path bottomShadePath = Path();
    double shadeHeight = h * 0.15; // Height of the shaded area from bottom
    bottomShadePath.moveTo((w - bodyBottomWidth * 0.98) / 2, h - shadeHeight); // Start slightly inside
    bottomShadePath.lineTo((w - bodyBottomWidth * 0.98) / 2 + bodyBottomWidth * 0.98, h - shadeHeight);
    bottomShadePath.lineTo((w - bodyBottomWidth) / 2 + bodyBottomWidth, h);
    bottomShadePath.lineTo((w - bodyBottomWidth) / 2, h);
    bottomShadePath.close();
    canvas.drawPath(bottomShadePath, darkBodyPaint);
  }

  @override
  bool shouldRepaint(covariant BucketPainter oldDelegate) =>
      oldDelegate.rimColor != rimColor ||
          oldDelegate.bodyColor != bodyColor ||
          oldDelegate.size != size; // Though actualSize from paint method is used
}