import 'dart:async';
import 'package:flutter/material.dart';

class RainLockOverlay extends StatefulWidget {
  final VoidCallback onUnlock;

  const RainLockOverlay({super.key, required this.onUnlock});

  @override
  State<RainLockOverlay> createState() => _RainLockOverlayState();
}

class _RainLockOverlayState extends State<RainLockOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onUnlock();
      }
    });
  }

  void _onHoldStart(TapDownDetails details) {
    _controller.forward();
  }

  void _onHoldEnd([dynamic _]) {
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.88),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: Color(0xFF00E5FF),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'RAIN & SWEAT LOCK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Ghost touches from rain and sweat droplets are disabled.\nPress and hold the button below to unlock.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 48),

              // Interactive Unlock Button with Circular Progress
              GestureDetector(
                onTapDown: _onHoldStart,
                onTapUp: _onHoldEnd,
                onTapCancel: () => _onHoldEnd(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return CircularProgressIndicator(
                            value: _controller.value,
                            strokeWidth: 6,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00E5FF),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open, color: Colors.white, size: 28),
                          SizedBox(height: 2),
                          Text(
                            'HOLD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

