import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'snake_game.dart';

void main() {
  runApp(
    GameWidget<SnakeGame>(
      game: SnakeGame(),
      overlayBuilderMap: {
        'GameOver': (context, SnakeGame game) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '游戏结束',
                  style: TextStyle(fontSize: 32, color: Colors.red),
                ),
                ElevatedButton(
                  onPressed: () {
                    game.reset();
                    game.overlays.remove('GameOver');
                  },
                  child: const Text('重新开始'),
                ),
              ],
            ),
          );
        },
        'DirectionPad': (context, SnakeGame game) {
          // 方向按钮的灰色棋盘背景
          return Positioned(
            right: 24,
            bottom: 24,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[300],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 棋盘格背景
                  for (int y = 0; y < 3; y++)
                    for (int x = 0; x < 3; x++)
                      Positioned(
                        left: x * 46.7,
                        top: y * 46.7,
                        child: Container(
                          width: 46.7,
                          height: 46.7,
                          decoration: BoxDecoration(
                            color: ((x + y) % 2 == 0)
                                ? Colors.grey[200]
                                : Colors.grey[400],
                            border: Border.all(color: Colors.grey[500]!, width: 0.5),
                          ),
                        ),
                      ),
                  // 上
                  Positioned(
                    left: 46.7,
                    top: 0,
                    child: _DirectionButton(
                      label: '上',
                      icon: Icons.keyboard_arrow_up,
                      onTap: () => game.setDirection(Direction.up),
                    ),
                  ),
                  // 下
                  Positioned(
                    left: 46.7,
                    top: 93.4,
                    child: _DirectionButton(
                      label: '下',
                      icon: Icons.keyboard_arrow_down,
                      onTap: () => game.setDirection(Direction.down),
                    ),
                  ),
                  // 左
                  Positioned(
                    left: 0,
                    top: 46.7,
                    child: _DirectionButton(
                      label: '左',
                      icon: Icons.keyboard_arrow_left,
                      onTap: () => game.setDirection(Direction.left),
                    ),
                  ),
                  // 右
                  Positioned(
                    left: 93.4,
                    top: 46.7,
                    child: _DirectionButton(
                      label: '右',
                      icon: Icons.keyboard_arrow_right,
                      onTap: () => game.setDirection(Direction.right),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      },
      initialActiveOverlays: const ['DirectionPad'],
    ),
  );
}

/// 单个方向按钮，带灰色背景和文字
class _DirectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46.7,
      height: 46.7,
      child: Material(
        color: Colors.grey[600],
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
