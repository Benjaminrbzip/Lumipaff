import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../res/colors.dart';
import '../widgets/secondary_button.dart';
import '../widgets/game_countdown_overlay.dart';
import '../widgets/game_over_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/bluetooth_service.dart';

enum SimonPhase { memorise, reproduit, showResult }

class LumiSimonGamePage extends StatefulWidget {
  const LumiSimonGamePage({super.key});

  @override
  State<LumiSimonGamePage> createState() => _LumiSimonGamePageState();
}

class _LumiSimonGamePageState extends State<LumiSimonGamePage> {
  // Les 5 boutons actifs de la croix (indices ESP32)
  // Bouton 2 = index 1 (haut)
  // Bouton 4 = index 3 (gauche)
  // Bouton 5 = index 4 (centre)
  // Bouton 6 = index 5 (droite)
  // Bouton 8 = index 7 (bas)
  static const List<int> simonButtons = [1, 3, 4, 5, 7];

  // Couleurs associées (pour l'affichage écran)
  static const Map<int, Color> buttonColors = {
    1: Colors.redAccent,     // Haut = Rouge
    3: Colors.greenAccent,   // Gauche = Vert
    4: Colors.yellowAccent,  // Centre = Jaune
    5: Colors.blueAccent,    // Droite = Bleu
    7: Colors.purpleAccent,  // Bas = Magenta
  };

  static const Map<int, String> buttonLabels = {
    1: '▲',
    3: '◀',
    4: '●',
    5: '▶',
    7: '▼',
  };

  int _level = 1;
  SimonPhase _phase = SimonPhase.memorise;
  List<int> _sequence = []; // La séquence complète à reproduire
  int _playerStep = 0; // Position du joueur dans la séquence
  int? _highlightedButton; // Bouton actuellement allumé (pour l'affichage)

  bool _gameStarted = false;
  bool _gameOver = false;

  StreamSubscription<Map<String, dynamic>>? _bleSubscription;
  Timer? _displayTimer;

  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _bleSubscription = AppBleService().buttonEvents.listen((event) {
      if (mounted && _gameStarted && !_gameOver && _phase == SimonPhase.reproduit) {
        int? btn = event['buttonValue'];
        if (btn != null) {
          int index = btn - 1; // BTN:1 = index 0
          if (simonButtons.contains(index)) {
            _onPlayerPress(index);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    AppBleService().sendCommand("BASE");
    _bleSubscription?.cancel();
    _displayTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    AppBleService().sendCommand("SIMON");
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
    // Ajouter un bouton aléatoire à la séquence
    int nextButton = simonButtons[_rng.nextInt(simonButtons.length)];
    _sequence.add(nextButton);

    setState(() {
      _phase = SimonPhase.memorise;
      _playerStep = 0;
      _highlightedButton = null;
    });

    // Montrer la séquence avec un délai
    _showSequence();
  }

  void _showSequence() {
    int stepIndex = 0;
    // Délai entre chaque note : plus c'est avancé, plus c'est rapide
    int delayMs = math.max(300, 700 - (_level * 30));

    // Petit délai au démarrage pour laisser le temps de lire "MEMORISE"
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _gameOver) return;

      _displayTimer = Timer.periodic(Duration(milliseconds: delayMs), (timer) {
        if (!mounted || _gameOver) {
          timer.cancel();
          return;
        }

        if (stepIndex < _sequence.length) {
          int btn = _sequence[stepIndex];

          // Allumer le bouton
          setState(() => _highlightedButton = btn);
          AppBleService().sendCommand("S:$btn:1");

          // Eteindre après un court instant
          Future.delayed(Duration(milliseconds: (delayMs * 0.6).round()), () {
            if (!mounted) return;
            setState(() => _highlightedButton = null);
            AppBleService().sendCommand("S:$btn:0");
          });

          stepIndex++;
        } else {
          timer.cancel();
          // Passer en phase reproduction
          Future.delayed(Duration(milliseconds: delayMs), () {
            if (!mounted || _gameOver) return;
            setState(() {
              _phase = SimonPhase.reproduit;
              _playerStep = 0;
            });
          });
        }
      });
    });
  }

  void _onPlayerPress(int buttonIndex) {
    if (_phase != SimonPhase.reproduit || _gameOver) return;

    // Flash visuel du bouton pressé
    setState(() => _highlightedButton = buttonIndex);
    AppBleService().sendCommand("S:$buttonIndex:1");
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _highlightedButton = null);
      AppBleService().sendCommand("S:$buttonIndex:0");
    });

    // Vérification
    if (buttonIndex == _sequence[_playerStep]) {
      // Correct !
      _playerStep++;
      if (_playerStep >= _sequence.length) {
        // Séquence complète — niveau suivant !
        setState(() {
          _phase = SimonPhase.showResult;
          _level++;
        });

        // Petit flash de victoire avant le prochain niveau
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted || _gameOver) return;
          _addStepAndShowSequence();
        });
      }
    } else {
      // ERREUR — Game Over !
      _displayTimer?.cancel();
      AppBleService().sendCommand("BASE");
      FirebaseService().saveScore(gameMode: 'lumi_simon', level: _level);
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

                // Cross layout for the 5 Simon buttons
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Haut (index 1)
                      Positioned(
                        top: 0,
                        child: _buildSimonButton(1),
                      ),
                      // Gauche (index 3)
                      Positioned(
                        left: 0,
                        child: _buildSimonButton(3),
                      ),
                      // Centre (index 4)
                      _buildSimonButton(4),
                      // Droite (index 5)
                      Positioned(
                        right: 0,
                        child: _buildSimonButton(5),
                      ),
                      // Bas (index 7)
                      Positioned(
                        bottom: 0,
                        child: _buildSimonButton(7),
                      ),
                    ],
                  ),
                ),

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
              gameName: 'Lumi Simon',
              level: _level,
              onExit: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }

  Widget _buildSimonButton(int index) {
    bool isHighlighted = _highlightedButton == index;
    Color baseColor = buttonColors[index] ?? Colors.grey;
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
        child: Text(
          buttonLabels[index] ?? '',
          style: TextStyle(
            color: isHighlighted ? Colors.white : Colors.white38,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
