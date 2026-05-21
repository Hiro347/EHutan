import 'package:flutter/material.dart';

class Stacked3DButton extends StatefulWidget {
  final VoidCallback? onTap;
  final double size;

  const Stacked3DButton({super.key, this.onTap, this.size = 80});

  @override
  State<Stacked3DButton> createState() => _Stacked3DButtonState();
}

class _Stacked3DButtonState extends State<Stacked3DButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _pressAnim = Tween<double>(
      begin: 0,
      end: 5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) async {
    await _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pressAnim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _pressAnim.value),
            child: child,
          );
        },
        child: AnimatedBuilder(
          animation: _pressAnim,
          builder: (context, _) {
            final pressed = _pressAnim.value > 2;
            return SizedBox(
              width: s,
              height: s,
              child: _BaseLayer(size: s, pressed: pressed),
            );
          },
        ),
      ),
    );
  }
}

// ── LAYER 1 — Base layer (medium dark green) ──────────────────────────────
class _BaseLayer extends StatelessWidget {
  final double size;
  final bool pressed;
  const _BaseLayer({required this.size, required this.pressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0D5C1E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(children: [_TopLayer(size: size)]),
    );
  }
}

// ── LAYER 2 — Top surface (bright green gradient + glossy shine + icon) ───
class _TopLayer extends StatelessWidget {
  final double size;
  const _TopLayer({required this.size});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 3,
      left: 3,
      right: 3,
      bottom: 8, // Creates the bottom gap for the 3D base layer
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFA8F5B0),
              Color(0xFF5DE870),
              Color(0xFF28D44E),
              Color(0xFF1FB840),
            ],
            stops: [0.0, 0.35, 0.70, 1.0],
          ),
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            // Inner top highlight (glossy)
            BoxShadow(
              color: Colors.white.withOpacity(0.55),
              offset: const Offset(0, 2),
              blurRadius: 6,
              spreadRadius: -2,
            ),
            // Inner bottom shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              offset: const Offset(0, -2),
              blurRadius: 4,
              spreadRadius: -2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glossy shine overlay (top portion)
            Positioned(
              top: 3,
              left: 6,
              right: 6,
              child: Container(
                height: (size * 0.35),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.5),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Plus icon
            const Icon(
              Icons.add,
              color: Colors.white,
              size: 32,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
