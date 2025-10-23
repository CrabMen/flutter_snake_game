import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'bubble_game.dart';

class StartOverlay extends StatelessWidget {
  final BubbleGame game;
  const StartOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '目标：在60秒内清除所有红色NPC',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '操作：摇杆或WASD/方向键移动；更大即可吞并；⚡加速，😈护盾',
            style: TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              game.handleStart();
            },
            child: const Text('开始挑战'),
          ),
        ],
      ),
    );
  }
}

class RetryOverlay extends StatelessWidget {
  final BubbleGame game;
  const RetryOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '游戏结束：被更大的泡泡吞并或时间耗尽',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              game.retryLevel();
            },
            child: const Text('重试本关'),
          ),
        ],
      ),
    );
  }
}

void main() {
  final game = BubbleGame();
  runApp(
    GameWidget<BubbleGame>(
      game: game,
      overlayBuilderMap: {
        'Start': (context, BubbleGame g) => StartOverlay(game: g),
        'Retry': (context, BubbleGame g) => RetryOverlay(game: g),
      },
      initialActiveOverlays: const ['Start'],
    ),
  );
}
