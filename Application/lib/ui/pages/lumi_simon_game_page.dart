import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../res/colors.dart';
import '../../res/assets.dart';
import '../widgets/secondary_button.dart';
import '../widgets/game_countdown_overlay.dart';
import '../widgets/game_over_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/bluetooth_service.dart';
import '../../services/audio_service.dart';

enum SimonPhase { memorise, reproduit, showResult }
enum SimonDifficulty { normal, hard }

class LumiSimonGamePage extends StatefulWidget {
  const LumiSimonGamePage({super.key});

  @override
  State<LumiSimonGamePage> createState() => _LumiSimonGamePageState();
}

class _LumiSimonGamePageState extends State<LumiSimonGamePage> {
  // Normal: 5 boutons en croix
  static const List<int> normalButtons = [1, 3, 4, 5, 7];
  // Hard: tous les 9 boutons
  static const List<int> hardButtons = [0, 1, 2, 3, 4, 5, 6, 7, 8];

  // Couleurs associées (affichage écran)
  static const Map<int, Color> allButtonColors = {
    0: Colors.redAccent,     // Rouge
    1: Colors.greenAccent,   // Vert
    2: Colors.blueAccent,    // Bleu
    3: Colors.yellowAccent,  // Jaune
    4: Colors.cyanAccent,    // Cyan
    5: Colors.purpleAccent,  // Magenta
    6: Colors.orangeAccent,  // Orange
    7: Colors.white,         // Blanc
    8: Color(0xFFAA55FF),    // Violet
  };

  // Rotation de la flèche (base = pointe à gauche)
  // Pour tourner : haut=π/2, droite=π, bas=-π/2, diagonales en conséquence
  static const Map<int, double> arrowRotations = {
    0: math.pi / 4,
    1: math.pi / 2,
    2: 3 * math.pi / 4,
    3: 0,
    // 4 = centre, pas de flèche
    5: math.pi,
    6: -math.pi / 4,
    7: -math.pi / 2,
    8: -3 * math.pi / 4,
  };

  SimonDifficulty? _difficulty; // null = pas encore choisi
  int _level = 1;
  SimonPhase _phase = SimonPhase.memorise;
  List<int> _sequence = [];
  int _playerStep = 0;
  int? _highlightedButton;

  bool _gameStarted = false;
  bool _gameOver = false;

  StreamSubscription<Map<String, dynamic>>? _bleSubscription;
  Timer? _displayTimer;

  final math.Random _rng = math.Random();

  List<int> get _activeButtons =>
      _difficulty == SimonDifficulty.hard ? hardButtons : normalButtons;

  String get _firebaseMode =>
      _difficulty == SimonDifficulty.hard ? 'lumi_simon_hard' : 'lumi_simon';

  @override
  void initState() {
    super.initState();
    AudioService().pauseMusic();
    _bleSubscription = AppBleService().buttonEvents.listen((event) {
      if (mounted && _gameStarted && !_gameOver && _phase == SimonPhase.reproduit) {
        int? btn = event['buttonValue'];
        if (btn != null) {
          int index = btn - 1;
          if (_activeButtons.contains(index)) {
            _onPlayerPress(index);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    AudioService().resumeMusic();
    AppBleService().sendCommand("BASE");
    _bleSubscription?.cancel();
    _displayTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    if (_difficulty == SimonDifficulty.hard) {
      AppBleService().sendCommand("SIMON_HARD");
    } else {
      AppBleService().sendCommand("SIMON");
    }
    setState(() {
      _level = 1;
      _sequence = [];
      _playerStep = 0;
      _gameOver = false;
      _highlightedButton = null;
    });
    _addStepAndShowSequence();
  }

  void _addStepAndShowSequence() {
    int nextButton = _activeButtons[_rng.nextInt(_activeButtons.length)];
    _sequence.add(nextButton);

    setState(() {
      _phase = SimonPhase.memorise;
      _playerStep = 0;
      _highlightedButton = null;
    });

    _showSequence();
  }

  void _showSequence() {
    int stepIndex = 0;
    int delayMs = math.max(300, 700 - (_level * 30));

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _gameOver) return;

      _displayTimer = Timer.periodic(Duration(milliseconds: delayMs), (timer) {
        if (!mounted || _gameOver) {
          timer.cancel();
          return;
        }

        if (stepIndex < _sequence.length) {
          int btn = _sequence[stepIndex];

          setState(() => _highlightedButton = btn);
          AudioService().playSimonNote(btn);
          AppBleService().sendCommand("S:$btn:1");

          Future.delayed(Duration(milliseconds: (delayMs * 0.6).round()), () {
            if (!mounted) return;
            setState(() => _highlightedButton = null);
            AppBleService().sendCommand("S:$btn:0");
          });

          stepIndex++;
        } else {
          timer.cancel();
          // Dès que le dernier son est fini (environ la moitié du délai), on passe en phase "à toi"
          int finishDelay = (delayMs * 0.7).round();
          Future.delayed(Duration(milliseconds: finishDelay), () {
            if (!mounted || _gameOver) return;
            // Flash visuel pour indiquer le début du tour : SIMON réinitialise tout
            AppBleService().sendCommand(_difficulty == SimonDifficulty.hard ? "SIMON_HARD" : "SIMON");
            setState(() {
              _phase = SimonPhase.reproduit;
              _playerStep = 0;
            });
            debugPrint("Simon -> Début du tour joueur (Phase Reproduit) - Niveau $_level");
          });
        }
      });
    });
  }

  void _onPlayerPress(int buttonIndex) {
    if (_phase != SimonPhase.reproduit || _gameOver) return;

    setState(() => _highlightedButton = buttonIndex);
    AudioService().playSimonNote(buttonIndex);
    AppBleService().sendCommand("S:$buttonIndex:1");
    debugPrint("Simon -> Joueur presse: $buttonIndex (Attendu: ${_sequence[_playerStep]})");

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _highlightedButton = null);
      AppBleService().sendCommand("S:$buttonIndex:0");
    });

    if (buttonIndex == _sequence[_playerStep]) {
      _playerStep++;
      if (_playerStep >= _sequence.length) {
        setState(() {
          _phase = SimonPhase.showResult;
          _level++;
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted || _gameOver) return;
          _addStepAndShowSequence();
        });
      }
    } else {
      debugPrint("Simon -> ERREUR: Joueur presse $buttonIndex mais ${_sequence[_playerStep]} était attendu.");
      _displayTimer?.cancel();
      AppBleService().sendCommand("BASE");
      FirebaseService().saveScore(gameMode: _firebaseMode, level: _level);
      setState(() => _gameOver = true);
    }
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
                  'Lumi Simon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(flex: 2),

                // Level Indicator
                Text(
                  'Level : $_level',
                  style: const TextStyle(
                    color: kCyanColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (_difficulty != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _difficulty == SimonDifficulty.hard
                            ? Colors.redAccent
                            : kCyanColor,
                      ),
                    ),
                    child: Text(
                      _difficulty == SimonDifficulty.hard ? 'HARD' : 'NORMAL',
                      style: TextStyle(
                        color: _difficulty == SimonDifficulty.hard
                            ? Colors.redAccent
                            : kCyanColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                // Phase indicator
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _phase == SimonPhase.memorise
                        ? 'MEMORISE'
                        : _phase == SimonPhase.reproduit
                            ? 'A TOI !'
                            : 'BRAVO !',
                    key: ValueKey<SimonPhase>(_phase),
                    style: TextStyle(
                      color: _phase == SimonPhase.memorise
                          ? kPrimaryButtonColor
                          : _phase == SimonPhase.reproduit
                              ? const Color(0xFF4CAF50)
                              : kCyanColor,
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Button layout
                if (_difficulty == SimonDifficulty.hard)
                  _buildHardGrid()
                else
                  _buildNormalCross(),

                const Spacer(flex: 2),

                // Sequence progress
                if (_phase == SimonPhase.reproduit)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      '$_playerStep / ${_sequence.length}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 18,
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
                      AudioService().playSfx('audio/SFX/electronichit.mp3');
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Difficulty selection
          if (_difficulty == null)
            _buildDifficultySelection(),
          // Countdown overlay
          if (_difficulty != null && !_gameStarted)
            GameCountdownOverlay(
              onFinished: () {
                setState(() => _gameStarted = true);
                _startGame();
              },
            ),
          // Game Over screen
          if (_gameOver)
            GameOverScreen(
              gameName: _difficulty == SimonDifficulty.hard
                  ? 'Lumi Simon (Hard)'
                  : 'Lumi Simon',
              level: _level,
              onExit: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelection() {
    return Container(
      color: kPrimaryBackgroundColor.withOpacity(0.97),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'LUMI SIMON',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choisis ta difficulté',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            // Normal button
            GestureDetector(
              onTap: () => setState(() => _difficulty = SimonDifficulty.normal),
              child: Container(
                width: 220,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kCyanColor, width: 2),
                  color: kCyanColor.withOpacity(0.1),
                ),
                child: Column(
                  children: [
                    const Text(
                      'NORMAL',
                      style: TextStyle(
                        color: kCyanColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '5 boutons en croix',
                      style: TextStyle(
                        color: kCyanColor.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Hard button
            GestureDetector(
              onTap: () => setState(() => _difficulty = SimonDifficulty.hard),
              child: Container(
                width: 220,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent, width: 2),
                  color: Colors.redAccent.withOpacity(0.1),
                ),
                child: Column(
                  children: [
                    const Text(
                      'HARD',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '9 boutons — 9 couleurs',
                      style: TextStyle(
                        color: Colors.redAccent.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SecondaryButton(
                label: 'Retour',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalCross() {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, child: _buildSimonButton(1)),
          Positioned(left: 0, child: _buildSimonButton(3)),
          _buildSimonButton(4),
          Positioned(right: 0, child: _buildSimonButton(5)),
          Positioned(bottom: 0, child: _buildSimonButton(7)),
        ],
      ),
    );
  }

  Widget _buildHardGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 9,
          itemBuilder: (context, index) => _buildSimonButton(index),
        ),
      ),
    );
  }

  Widget _buildSimonButton(int index) {
    bool isHighlighted = _highlightedButton == index;
    Color baseColor = allButtonColors[index] ?? Colors.grey;
    Color displayColor = isHighlighted ? baseColor : baseColor.withOpacity(0.25);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: displayColor,
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: baseColor.withOpacity(0.8),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ]
            : null,
        border: Border.all(
          color: isHighlighted ? Colors.white : baseColor.withOpacity(0.5),
          width: 3,
        ),
      ),
      child: Center(
        child: index == 4
            ? Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHighlighted ? Colors.white : Colors.white38,
                ),
              )
            : Transform.rotate(
                angle: arrowRotations[index] ?? 0,
                child: Image.asset(
                  AppAssets.iconArrow,
                  width: 28,
                  height: 28,
                  color: isHighlighted ? Colors.white : Colors.white38,
                ),
              ),
      ),
    );
  }
}
