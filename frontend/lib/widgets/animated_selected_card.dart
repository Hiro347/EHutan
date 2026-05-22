import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/observation.dart';
import 'species_card.dart';

class AnimatedSelectedCard extends StatefulWidget {
  final Observation? observation;
  final VoidCallback onClear;
  final double bottomSheetMinHeight;

  const AnimatedSelectedCard({
    super.key,
    this.observation,
    required this.onClear,
    required this.bottomSheetMinHeight,
  });

  @override
  State<AnimatedSelectedCard> createState() => _AnimatedSelectedCardState();
}

class _AnimatedSelectedCardState extends State<AnimatedSelectedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Observation? _currentObs;

  @override
  void initState() {
    super.initState();
    _currentObs = widget.observation;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (_currentObs != null) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(AnimatedSelectedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.observation != oldWidget.observation) {
      if (widget.observation != null) {
        setState(() {
          _currentObs = widget.observation;
        });
        _controller.forward(from: 0.0);
      } else {
        setState(() {
          _currentObs = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentObs == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;
    
    const double originalWidth = 220.0;
    const double originalHeight = 310.0;
    const double targetScale = 0.45;
    const double visualHeight = originalHeight * targetScale;
    const double visualWidth = originalWidth * targetScale;

    final double centerTop = screenSize.height / 2 - originalHeight / 2 - 50; // slightly above true center
    final double centerLeft = screenSize.width / 2 - originalWidth / 2;

    final double visualEndTop = screenSize.height - widget.bottomSheetMinHeight - visualHeight - 16;
    const double visualEndLeft = 16.0;

    final double endTop = visualEndTop - (originalHeight - visualHeight) / 2;
    final double endLeft = visualEndLeft - (originalWidth - visualWidth) / 2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        
        double top;
        double left;
        double scale;
        double rotation;
        double opacity = 1.0;

        if (t < 0.25) {
          // Phase 1: Throw from bottom to center
          final pt = Curves.easeOutBack.transform(t / 0.25);
          top = centerTop + 300 * (1 - pt);
          left = centerLeft;
          scale = 0.3 + 0.7 * pt;
          rotation = (1 - pt) * math.pi / 3; // start with an angle
          opacity = pt.clamp(0.0, 1.0);
        } else if (t < 0.6) {
          // Phase 2: Stay in center and show clearly
          top = centerTop;
          left = centerLeft;
          scale = 1.0;
          rotation = 0.0;
        } else {
          // Phase 3: Shrink and move to bottom left
          final pt = Curves.easeInOutCubic.transform((t - 0.6) / 0.4);
          top = centerTop + (endTop - centerTop) * pt;
          left = centerLeft + (endLeft - centerLeft) * pt;
          scale = 1.0 - (1.0 - targetScale) * pt;
          rotation = 0.0;
        }

        return Positioned(
          top: top,
          left: left,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(scale, scale, 1.0)
              ..rotateZ(rotation),
            child: Opacity(
              opacity: opacity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: originalWidth,
                    height: originalHeight,
                    child: SpeciesCard(
                      observation: _currentObs!,
                      disableFlip: true,
                      onTap: t == 1.0 ? widget.onClear : () {},
                    ),
                  ),
                  if (t == 1.0)
                    Positioned(
                      top: -10,
                      right: -10,
                      child: GestureDetector(
                        onTap: widget.onClear,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          ),
                          child: const Icon(Icons.close, size: 28, color: Colors.white),
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
