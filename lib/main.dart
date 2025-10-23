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

class NextLevelOverlay extends StatelessWidget {
  final BubbleGame game;
  const NextLevelOverlay({super.key, required this.game});

  String _hintText(int currentLevel) {
    if (currentLevel == 1) {
      return '第2关玩法：仅有⚡闪电，加速至2.5倍，尽快清除NPC！';
    } else if (currentLevel == 2) {
      return '第3关玩法：⚡闪电+😈恶魔。⚡加速，😈护盾，合理利用组合！';
    }
    return '继续挑战下一关';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('挑战成功', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 12),
            Text(_hintText(game.currentLevel), style: const TextStyle(fontSize: 16, color: Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                game.startNextLevel();
              },
              child: const Text('继续挑战'),
            ),
          ],
        ),
      ),
    );
  }
}

class VictoryOverlay extends StatelessWidget {
  final BubbleGame game;
  const VictoryOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('恭喜通关！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 8),
            const Text('撒花庆祝🎉', style: TextStyle(fontSize: 16, color: Colors.black87)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                game.restartGame();
              },
              child: const Text('重新开始第一关'),
            ),
          ],
        ),
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
        'NextLevel': (context, BubbleGame g) => NextLevelOverlay(game: g),
        'Victory': (context, BubbleGame g) => VictoryOverlay(game: g),
      },
      initialActiveOverlays: const ['Start'],
    ),
  );
}
