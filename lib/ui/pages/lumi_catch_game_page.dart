import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../res/colors.dart';
import '../../res/assets.dart';
import '../widgets/secondary_button.dart';
import '../widgets/game_countdown_overlay.dart';
import '../widgets/game_over_screen.dart';
import '../../services/firebase_service.dart';

class GameLevel {
  final List<int> pattern;
  final int baseSpeedMs;
  GameLevel(this.pattern, this.baseSpeedMs);
}

class PatternDef {
  final List<int> sequence;
  final double speedFactor;
  PatternDef(this.sequence, this.speedFactor);
}

class LumiCatchGamePage extends StatefulWidget {
  const LumiCatchGamePage({super.key});

  @override
  State<LumiCatchGamePage> createState() => _LumiCatchGamePageState();
}

class _LumiCatchGamePageState extends State<LumiCatchGamePage> {
  int _score = 0;
  int _lives = 3;
  int _lightIndex = 0;
  bool _isPlaying = false;
  bool _gameStarted = false;
  bool _gameOver = false;
  Color _flashColor = Colors.transparent;

  int _currentLevelIndex = 0;
  int _patternStep = 0;
  Timer? _gameTimer;

  final List<PatternDef> _patterns = [
    PatternDef([0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1], 1.0),
    PatternDef([0, 1, 2, 3, 4, 5, 6, 7, 8], 1.0),
    PatternDef([8, 7, 6, 5, 4, 3, 2, 1, 0], 1.0),
    PatternDef([0, 1, 0, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 8, 7, 8, 7, 6, 5, 4, 3, 2, 1], 1.35),
    PatternDef([0, 1, 2, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1], 1.2),
    PatternDef([4, 3, 2, 1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5], 1.0),
  ];

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _lives = 3;
      _currentLevelIndex = 0;
      _patternStep = 0;
      _lightIndex = _getCurrentLevel().pattern[0];
      _isPlaying = true;
      _gameOver = false;
      _flashColor = Colors.transparent;
    });
    _timerTick();
  }

  void _nextLevel() {
    setState(() {
      _currentLevelIndex++;
      _patternStep = 0;
      _lightIndex = _getCurrentLevel().pattern[0];
    });
    _timerTick();
  }

  GameLevel _getCurrentLevel() {
    double extraSpeed = 130.0;
    // La vitesse supplémentaire diminue de 15% à chaque niveau.
    // Plus on avance, moins on retire de millisecondes.
    for (int i = 0; i < _currentLevelIndex; i++) {
      extraSpeed *= 0.85;
    }
    
    // Vitesse de base innatteignable (40ms) + la portion variable retravaillée
    int globalSpeed = (40.0 + extraSpeed).round();

    final def = _patterns[_currentLevelIndex % _patterns.length];
    int finalSpeedMs = (globalSpeed * def.speedFactor).round();
    
    return GameLevel(def.sequence, finalSpeedMs);
  }

  void _timerTick() {
    if (!_isPlaying) return;
    
    _gameTimer?.cancel();
    final level = _getCurrentLevel();

    _gameTimer = Timer(Duration(milliseconds: level.baseSpeedMs), () {
      if (!mounted || !_isPlaying) return;
      
      setState(() {
        _patternStep++;
        if (_patternStep >= level.pattern.length) {
          _patternStep = 0;
        }
        _lightIndex = level.pattern[_patternStep];
      });
      _timerTick();
    });
  }

  void _onPush() {
    if (!_isPlaying) return;

    setState(() {
      if (_lightIndex == 4) {
        _score += 30;
        _flashBackground(Colors.blueAccent.withOpacity(0.3));
        _nextLevel();
      } else if (_lightIndex == 3 || _lightIndex == 5) {
        _score += 20;
        _flashBackground(Colors.greenAccent.withOpacity(0.3));
        _nextLevel();
      } else {
        _lives--;
        _flashBackground(Colors.red.withOpacity(0.3));
        if (_lives <= 0) {
          _isPlaying = false;
          _gameTimer?.cancel();
          FirebaseService().saveScore(
            gameMode: 'lumi_catch', 
            score: _score, 
            level: _currentLevelIndex + 1
          );
          setState(() => _gameOver = true);
        }
      }
    });
  }

  void _flashBackground(Color color) {
    _flashColor = color;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _flashColor = Colors.transparent);
      }
    });
  }

  Widget _buildCircle(int index) {
    bool isOn = _lightIndex == index;
    bool isCenter = index == 4;
    double size = isCenter ? 44.0 : 36.0;

    Color glowColor;
    if (isCenter) {
      glowColor = Colors.blueAccent;
    } else if (index == 3 || index == 5) {
      glowColor = Colors.greenAccent;
    } else {
      glowColor = Colors.redAccent;
    }

    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.symmetric(vertical: isCenter ? 8.0 : 6.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOn ? glowColor : Colors.white24,
        boxShadow: isOn 
            ? [BoxShadow(color: glowColor.withOpacity(0.8), blurRadius: 16, spreadRadius: 2)]
            : null,
      ),
    );
  }

  Widget _buildHearts() {
    return Row(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: SvgPicture.asset(
            AppAssets.iconHeart,
            width: 36,
            height: 36,
            colorFilter: ColorFilter.mode(
               index < _lives ? kCyanColor : Colors.white24, 
               BlendMode.srcIn
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main game content
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: _flashColor == Colors.transparent ? kPrimaryBackgroundColor : _flashColor,
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Lumi Catch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kCyanColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kCyanColor),
                        ),
                        child: Text(
                          'Lvl ${_currentLevelIndex + 1}',
                          style: const TextStyle(color: kCyanColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildHearts(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Score :',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                color: kPrimaryButtonColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 440,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(color: kCyanColor, width: 6),
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 156,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: kPrimaryButtonColor, width: 4),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(9, (index) => _buildCircle(index)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: GestureDetector(
                      onTapDown: (_) => _onPush(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: kCyanColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kCyanColor, width: 2),
                        ),
                        child: const Text(
                          'PUSH (Buzzer)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kCyanColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: SecondaryButton(
                      label: 'Stop Game',
                      onPressed: () {
                        _isPlaying = false;
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Countdown overlay
          if (!_gameStarted)
            GameCountdownOverlay(
              onFinished: () {
                setState(() => _gameStarted = true);
                _startGame();
              },
            ),
          // Game Over screen
          if (_gameOver)
            GameOverScreen(
              gameName: 'Lumi Catch',
              score: _score,
              level: _currentLevelIndex + 1,
              onExit: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
