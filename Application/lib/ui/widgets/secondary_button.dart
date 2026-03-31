import 'package:flutter/material.dart';
import '../../res/colors.dart';

class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = kCyanColor,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isHovering = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: widget.color,
            elevation: 0,
            shape: StadiumBorder(
              side: BorderSide(color: widget.color, width: 1.5),
            ), 
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.pressed)) {
                  return widget.color.withOpacity(0.2);
                }
                return null;
              },
            ),
          ),
          onPressed: widget.onPressed,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
