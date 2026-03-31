import 'dart:async';
import 'package:flutter/material.dart';
import '../../res/colors.dart';
import '../widgets/secondary_button.dart';
import '../widgets/game_countdown_overlay.dart';
import '../widgets/game_over_screen.dart';
import '../../services/firebase_service.dart';

enum SimonPhase { memorise, reproduit }

class LumiSimonGamePage extends StatefulWidget {
  const LumiSimonGamePage({super.key});

  @override
  State<LumiSimonGamePage> createState() => _LumiSimonGamePageState();
}

class _LumiSimonGamePageState extends State<LumiSimonGamePage> {
  int _level = 1;
  SimonPhase _phase = SimonPhase.memorise;
  Timer? _mockPhaseTimer;

  bool _gameStarted = false;
  bool _gameOver = false;

  @override
  void dispose() {
    _mockPhaseTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _level = 1;
      _phase = SimonPhase.memorise;
      _gameOver = false;
    });
    _startSimulatedPhases();
  }

  void _startSimulatedPhases() {
    _mockPhaseTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      setState(() {
        if (_phase == SimonPhase.memorise) {
          _phase = SimonPhase.reproduit;
        } else {
          _phase = SimonPhase.memorise;
          _level++;
        }
      });
    });
  }

  /// Appelé quand l'ESP32 signale une erreur du joueur
  void triggerGameOver() {
    if (!mounted || _gameOver) return;
    _mockPhaseTimer?.cancel();
    FirebaseService().saveScore(gameMode: 'lumi_simon', level: _level);
    setState(() => _gameOver = true);
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
                    _phase == SimonPhase.memorise ? 'MEMORISE' : 'REPRODUIT',
                    key: ValueKey<SimonPhase>(_phase),
                    style: TextStyle(
                      color: _phase == SimonPhase.memorise ? kPrimaryButtonColor : const Color(0xFF4CAF50),
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                const Spacer(flex: 3),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    '(Les entrées joueurs se feront via les boutons de l\'ESP32)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
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
          // Game Over screen (déclenché manuellement via l'ESP32 ou un échec)
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
}
