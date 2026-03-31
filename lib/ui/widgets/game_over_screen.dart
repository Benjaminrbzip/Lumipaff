import 'package:flutter/material.dart';
import '../../res/colors.dart';
import 'secondary_button.dart';

/// A reusable full-screen game recap overlay.
/// Displays [score] and/or [level] depending on what is provided.
class GameOverScreen extends StatelessWidget {
  final int? score;
  final int? level;
  final String gameName;
  final VoidCallback onExit;

  const GameOverScreen({
    super.key,
    this.score,
    this.level,
    required this.gameName,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kPrimaryBackgroundColor.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Finish Title
            const Text(
              'FINISH',
              style: TextStyle(
                color: kCyanColor,
                fontSize: 46,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                shadows: [
                  Shadow(
                    color: kCyanColor,
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              gameName,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Spacer(flex: 1),
            // Stats Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kCyanColor.withOpacity(0.35), width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kCyanColor.withOpacity(0.1),
                    kPrimaryButtonColor.withOpacity(0.06),
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'RECAP',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (score != null) ...[
                    const Text(
                      'Score',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$score',
                      style: const TextStyle(
                        color: kPrimaryButtonColor,
                        fontSize: 56,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: kPrimaryButtonColor,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (score != null && level != null) 
                    const SizedBox(height: 28),
                  if (level != null) ...[
                    const Text(
                      'Level',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$level',
                      style: const TextStyle(
                        color: kCyanColor,
                        fontSize: 56,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: kCyanColor,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(flex: 2),
            // Exit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SecondaryButton(
                label: 'Retour',
                onPressed: onExit,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
