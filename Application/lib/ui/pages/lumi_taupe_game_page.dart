import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../res/colors.dart';
import '../widgets/secondary_button.dart';
import '../widgets/game_countdown_overlay.dart';
import '../widgets/game_over_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/bluetooth_service.dart';

class LumiTaupeGamePage extends StatefulWidget {
  const LumiTaupeGamePage({super.key});

  @override
  State<LumiTaupeGamePage> createState() => _LumiTaupeGamePageState();
}

class PodInfo {
  int state = 0; // 0: OFF (bleu), 1: GREEN, 2: ORANGE
  Timer? greenTimer;
  Timer? orangeTimer;

  void cancelTimers() {
    greenTimer?.cancel();
    orangeTimer?.cancel();
  }
}

class _LumiTaupeGamePageState extends State<LumiTaupeGamePage> {
  int _timeLeft = 45;
  Timer? _timer;

  int _score = 0;
  int _multiplier = 1;
  double _multiplierProgress = 0.0;
  final int _maxMultiplier = 4;
  final int _hitsToIncreaseMultiplier = 3;

  final List<PodInfo> _pods = List.generate(9, (_) => PodInfo());

  int _spawnIntervalMs = 600;
  int _moleLifeTimeMs = 1400;
  Timer? _masterSpawnTimer;

  Timer? _decayTimer;

  bool _gameStarted = false;
  bool _gameOver = false;

  StreamSubscription<Map<String, dynamic>>? _bleSubscription;

  @override
  void initState() {
    super.initState();
    _bleSubscription = AppBleService().buttonEvents.listen((event) {
      if (mounted && _gameStarted && !_gameOver) {
        int? btn = event['buttonValue'];
        if (btn != null && btn >= 1 && btn <= 9) {
          _onBuzzerTap(btn - 1); // BTN:1 = index 0
        }
      }
    });
  }

  @override
  void dispose() {
    AppBleService().sendCommand("BASE");
    _bleSubscription?.cancel();
    _timer?.cancel();
    _decayTimer?.cancel();
    _masterSpawnTimer?.cancel();
    for (var pod in _pods) {
      pod.cancelTimers();
    }
    super.dispose();
  }

  void _startGame() {
    AppBleService().sendCommand("TAUPE");
    setState(() {
      _timeLeft = 45;
      _score = 0;
      _multiplier = 1;
      _multiplierProgress = 0.0;
      _spawnIntervalMs = 600;
      _moleLifeTimeMs = 1400;
      for (var pod in _pods) {
        pod.cancelTimers();
        pod.state = 0;
      }
      _gameOver = false;
    });
    _startTimer();
    _startMasterSpawner();
    _startDecayTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        _masterSpawnTimer?.cancel();
        for (var pod in _pods) {
          pod.cancelTimers();
        }
        _decayTimer?.cancel();
        AppBleService().sendCommand("BASE");
        FirebaseService().saveScore(gameMode: 'lumi_taupe', score: _score);
        setState(() => _gameOver = true);
      }
    });
  }

  void _startDecayTimer() {
    _decayTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _timeLeft <= 0) return;
      
      setState(() {
        _multiplierProgress -= (16.0 / 4000.0);
        
        if (_multiplierProgress <= 0.0) {
          if (_multiplier > 1) {
            _multiplier--;
            _multiplierProgress += _hitsToIncreaseMultiplier; 
          } else {
            _multiplierProgress = 0.0;
          }
        }
      });
    });
  }

  void _startMasterSpawner() {
    _masterSpawnTimer?.cancel();
    _scheduleNextMole();
  }

  void _scheduleNextMole() {
    _masterSpawnTimer = Timer(Duration(milliseconds: _spawnIntervalMs), () {
      if (!mounted || _timeLeft <= 0 || _gameOver) return;
      _spawnRandomMole();
      _scheduleNextMole();
    });
  }

  void _spawnRandomMole() {
    List<int> inactiveIndices = [];
    for (int i = 0; i < 9; i++) {
      if (_pods[i].state == 0) inactiveIndices.add(i);
    }

    if (inactiveIndices.isEmpty) return;

    int targetIndex = inactiveIndices[math.Random().nextInt(inactiveIndices.length)];
    
    setState(() {
      _pods[targetIndex].state = 1; // GREEN
    });
    AppBleService().sendCommand("T:$targetIndex:1"); // Vert sur l'ERP

    int greenDuration = (_moleLifeTimeMs * 0.6).round();
    int orangeDuration = (_moleLifeTimeMs * 0.4).round();

    _pods[targetIndex].greenTimer = Timer(Duration(milliseconds: greenDuration), () {
      if (!mounted || _pods[targetIndex].state != 1) return;
      setState(() {
        _pods[targetIndex].state = 2; // ORANGE
      });
      AppBleService().sendCommand("T:$targetIndex:2"); // Orange sur l'ERP

      _pods[targetIndex].orangeTimer = Timer(Duration(milliseconds: orangeDuration), () {
        if (!mounted || _pods[targetIndex].state != 2) return;
        setState(() {
          _pods[targetIndex].state = 0; // OFF
        });
        AppBleService().sendCommand("T:$targetIndex:0"); // Bleu (repos) sur l'ERP
      });
    });
  }

  void _onBuzzerTap(int index) {
    if (_timeLeft <= 0 || !_gameStarted || _gameOver) return;
    
    setState(() {
      int state = _pods[index].state;

      if (state == 1 || state == 2) {
        // HIT
        if (state == 1) {
          _score += 10 * _multiplier;
        } else if (state == 2) {
          _score += 5 * _multiplier;
        }
        
        if (_multiplier < _maxMultiplier) {
          _multiplierProgress += 1.0;
          if (_multiplierProgress >= _hitsToIncreaseMultiplier) {
            _multiplier++;
            if (_multiplier >= _maxMultiplier) {
              _multiplier = _maxMultiplier;
              _multiplierProgress = _hitsToIncreaseMultiplier.toDouble();
            } else {
              _multiplierProgress -= _hitsToIncreaseMultiplier; 
            }
          }
        } else {
          _multiplierProgress = _hitsToIncreaseMultiplier.toDouble(); 
        }

        if (_spawnIntervalMs > 300) _spawnIntervalMs -= 25;
        if (_moleLifeTimeMs > 500) _moleLifeTimeMs -= 25;

        _pods[index].cancelTimers();
        _pods[index].state = 0;
        AppBleService().sendCommand("T:$index:0"); // Retour bleu
      } else {
        // MISS
        _score -= 4;
        if (_score < 0) _score = 0;
        _multiplier = 1;
        _multiplierProgress = 0.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main game content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Lumi Taupe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(flex: 1),
                // Score Section
                Column(
                  children: [
                    const Text(
                      'Score :',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        color: kPrimaryButtonColor,
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 1),
                // Timer & Multiplier Section
                Center(
                  child: SizedBox(
                    width: 280, 
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Timer Circle
                        Positioned(
                          left: 0,
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kCyanColor.withOpacity(0.3),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kPrimaryBackgroundColor,
                                  ),
                                ),
                                CircularProgressIndicator(
                                  value: _timeLeft / 60.0,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.white10,
                                  valueColor: const AlwaysStoppedAnimation<Color>(kCyanColor),
                                ),
                                Center(
                                  child: Text(
                                    '${_timeLeft}s',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Multiplier Bar
                        Positioned(
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'x$_multiplier',
                                style: const TextStyle(
                                  color: kPrimaryButtonColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 24,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kPrimaryButtonColor, width: 4),
                                ),
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: FractionallySizedBox(
                                    heightFactor: (_multiplierProgress / _hitsToIncreaseMultiplier).clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: kPrimaryButtonColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                // Pod status indicators (read-only, no tap)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        bool isActive = _pods[index].state != 0;
                        Color podColor = Colors.blueAccent.withOpacity(0.3);
                        if (isActive) {
                          podColor = _pods[index].state == 1 ? Colors.greenAccent : Colors.orangeAccent;
                        }
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: podColor,
                            boxShadow: isActive
                                ? [BoxShadow(color: podColor.withOpacity(0.8), blurRadius: 16, spreadRadius: 2)]
                                : null,
                            border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                // Info text
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    'Appuie sur les boutons de l\'ERP !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Stop Game Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: SecondaryButton(
                    label: 'Stop Game',
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],
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
              gameName: 'Lumi Taupe',
              score: _score,
              onExit: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
