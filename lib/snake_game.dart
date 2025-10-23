import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum Direction { up, down, left, right }

class SnakeGame extends FlameGame with HasKeyboardHandlerComponents {
  static const int rowCount = 20;
  static const int colCount = 20;
  double cellSize = 20.0;

  List<Point<int>> snake = [Point(10, 10)];
  Direction direction = Direction.right;
  Point<int> food = Point(5, 5);
  double stepTime = 0.2;
  double _timer = 0.0;
  bool isGameOver = false;

  @override
  Future<void> onLoad() async {
    reset();
  }

  void reset() {
    snake = [Point(10, 10)];
    direction = Direction.right;
    food = _randomFood();
    isGameOver = false;
    _timer = 0.0;
  }

  Point<int> _randomFood() {
    final random = Random();
    Point<int> newFood;
    do {
      newFood = Point(
        random.nextInt(colCount - 2) + 1, // 不生成在墙上
        random.nextInt(rowCount - 2) + 1,
      );
    } while (snake.contains(newFood));
    return newFood;
  }

  @override
  void update(double dt) {
    if (isGameOver) return;
    _timer += dt;
    if (_timer >= stepTime) {
      _timer = 0.0;
      _moveSnake();
    }
  }

  void _moveSnake() {
    final head = snake.first;
    Point<int> newHead;
    switch (direction) {
      case Direction.up:
        newHead = Point(head.x, head.y - 1);
        break;
      case Direction.down:
        newHead = Point(head.x, head.y + 1);
        break;
      case Direction.left:
        newHead = Point(head.x - 1, head.y);
        break;
      case Direction.right:
        newHead = Point(head.x + 1, head.y);
        break;
    }

    // 检查撞墙或撞自己
    if (newHead.x == 0 ||
        newHead.x == colCount - 1 ||
        newHead.y == 0 ||
        newHead.y == rowCount - 1 ||
        snake.contains(newHead)) {
      isGameOver = true;
      overlays.add('GameOver');
      return;
    }

    snake.insert(0, newHead);

    if (newHead == food) {
      food = _randomFood();
    } else {
      snake.removeLast();
    }
  }

  @override
  void render(Canvas canvas) {
    // 绘制棋盘格和墙体
    final paintBg1 = Paint()..color = const Color(0xFFEEEEEE);
    final paintBg2 = Paint()..color = const Color(0xFFD6D6D6);
    final paintBorder = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final paintWall = Paint()..color = Colors.grey[700]!;

    for (int y = 0; y < rowCount; y++) {
      for (int x = 0; x < colCount; x++) {
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );
        // 墙体
        if (x == 0 || x == colCount - 1 || y == 0 || y == rowCount - 1) {
          canvas.drawRect(rect, paintWall);
        } else {
          // 棋盘格交错色
          canvas.drawRect(rect, ((x + y) % 2 == 0) ? paintBg1 : paintBg2);
        }
        // 边框
        canvas.drawRect(rect, paintBorder);
      }
    }

    // 绘制蛇
    final paintSnake = Paint()..color = Colors.green;
    for (final p in snake) {
      canvas.drawRect(
        Rect.fromLTWH(
          p.x * cellSize,
          p.y * cellSize,
          cellSize,
          cellSize,
        ),
        paintSnake,
      );
    }

    // 绘制食物
    final paintFood = Paint()..color = Colors.red;
    canvas.drawRect(
      Rect.fromLTWH(
        food.x * cellSize,
        food.y * cellSize,
        cellSize,
        cellSize,
      ),
      paintFood,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final double cellWidth = size.x / colCount;
    final double cellHeight = size.y / rowCount;
    cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event,
      Set<LogicalKeyboardKey> keysPressed,
      ) {
    super.onKeyEvent(event, keysPressed);
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowUp && direction != Direction.down) {
        direction = Direction.up;
      } else if (key == LogicalKeyboardKey.arrowDown && direction != Direction.up) {
        direction = Direction.down;
      } else if (key == LogicalKeyboardKey.arrowLeft && direction != Direction.right) {
        direction = Direction.left;
      } else if (key == LogicalKeyboardKey.arrowRight && direction != Direction.left) {
        direction = Direction.right;
      }
    }
    return KeyEventResult.handled;
  }

  void setDirection(Direction d) {
    if ((direction == Direction.up && d != Direction.down) ||
        (direction == Direction.down && d != Direction.up) ||
        (direction == Direction.left && d != Direction.right) ||
        (direction == Direction.right && d != Direction.left)) {
      direction = d;
    }
  }

  @override
  Color backgroundColor() => Colors.black;
}
