import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

// World constants
// 修改为可变以便在开始游戏时根据可视范围动态调整
double worldWidth = 1000;
double worldHeight = 1000;
double initialVisibleWidth = 50; // 初始期望可视范围宽度（世界单位）

class BubbleGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  late PlayerBubble player;
  final Random _rng = Random();
  late JoystickComponent joystick;
  // 地图元素引用，便于重设尺寸
  late RectangleComponent backgroundRect;
  late RectangleComponent wallTop;
  late RectangleComponent wallBottom;
  late RectangleComponent wallLeft;
  late RectangleComponent wallRight;
  // 道具图片精灵
  late Sprite shoeSprite;
  late Sprite shieldSprite;
  // 关卡与计时
  int currentLevel = 1;
  double timeLeft = 60.0;
  bool levelActive = false;
  bool started = false;
  bool npcSpawnedVisible = false; // 仅在NPC实际出现后才允许胜利判定
  // 小点补充计时
  int dotCount = 0;
  double replenishAccum = 0.0;
  // 定时道具生成
  int maxShoeItems = 8;
  int maxShieldItems = 8;
  double itemSpawnAccum = 0.0;
  double itemSpawnInterval = 8.0;
  // HUD
  late TextComponent levelText;
  late TextComponent timeText;

  @override
  Color backgroundColor() => Colors.white; // 移除整图灰色背景，使用白色背景

  @override
  Future<void> onLoad() async {
    // 启动时将世界尺寸设置为屏幕大小
    worldWidth = size.x;
    worldHeight = size.y;

    // 地图背景（透明，不再整图灰色）
    backgroundRect = RectangleComponent(
      position: Vector2.zero(),
      size: Vector2(worldWidth, worldHeight),
      paint: Paint()..color = const Color(0x00000000), // 透明
    );
    add(backgroundRect);

    // 围墙（深灰色）
    const double wallThickness = 10;
    final wallColor = Paint()..color = const Color(0xFF4A4A4A);
    wallTop = RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(worldWidth, wallThickness),
      paint: wallColor,
    ); // top
    add(wallTop);
    wallBottom = RectangleComponent(
      position: Vector2(0, worldHeight - wallThickness),
      size: Vector2(worldWidth, wallThickness),
      paint: wallColor,
    ); // bottom
    add(wallBottom);
    wallLeft = RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(wallThickness, worldHeight),
      paint: wallColor,
    ); // left
    add(wallLeft);
    wallRight = RectangleComponent(
      position: Vector2(worldWidth - wallThickness, 0),
      size: Vector2(wallThickness, worldHeight),
      paint: wallColor,
    ); // right
    add(wallRight);

    // 玩家泡泡（初始创建，开始时会重定位到中心）
    player = PlayerBubble(
      radius: 6,
      position: Vector2(worldWidth / 2, worldHeight / 2),
      color: Colors.blue,
    );
    add(player);

    // 相机跟随玩家
    camera.follow(player);

    // 初始相机缩放（与屏幕大小一致）
    _updateCameraZoom();

    // 道具使用 Emoji 表示，无需加载图片资源

    // HUD 文本（初始显示游戏名）
    levelText = TextComponent(text: '目标：在60秒内清除所有红色NPC', position: Vector2(10, 10), priority: 1000);
    timeText = TextComponent(text: '剩余: 60.0s  NPC: --', position: Vector2(10, 30), priority: 1000);
    // 设置HUD文本颜色为深色，提升可读性
    levelText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Colors.white70, offset: Offset(1, 1), blurRadius: 2)],
      ),
    );
    timeText.textRenderer = TextPaint(
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        shadows: [Shadow(color: Colors.white70, offset: Offset(1, 1), blurRadius: 2)],
      ),
    );
    add(levelText);
    add(timeText);

    // 移动端/网页虚拟摇杆（开始时即可使用）
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 22, paint: Paint()..color = Colors.black54),
      background: CircleComponent(radius: 80, paint: Paint()..color = Colors.black12),
      margin: const EdgeInsets.only(left: 24, bottom: 24),
    );
    add(joystick);


    // 注意：不主动开始关卡，等待用户点击开始按钮
  }

  Vector2 _randomInsideWorld({double offset = 0}) {
    return Vector2(
      _rng.nextDouble() * (worldWidth - 2 * offset) + offset,
      _rng.nextDouble() * (worldHeight - 2 * offset) + offset,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 玩家控制：来自摇杆或键盘
    final dirVec = joystick.delta;
    player.controlInput = (dirVec.length2 > 0)
        ? dirVec
        : _keyboardDirection;

    // 关卡倒计时与胜负判定
    if (levelActive) {
      timeLeft -= dt;
      final remainingNpc = children.whereType<NpcBubble>().where((n) => n.alive).length;
      // 标记NPC已出现，避免立即被判定为胜利
      if (!npcSpawnedVisible && remainingNpc > 0) {
        npcSpawnedVisible = true;
      }
      timeText.text = '剩余: ${timeLeft.toStringAsFixed(1)}s  NPC: $remainingNpc';

      if (npcSpawnedVisible && remainingNpc == 0) {
        // 通关：弹出提示覆盖层，进入下一关或最终胜利
        levelActive = false;
        levelText.text = '挑战成功';
        if (currentLevel < 3) {
          overlays.add('NextLevel');
        } else {
          showVictory();
        }
      } else if (timeLeft <= 0) {
        // 失败：暂停关卡并显示“再来一次”按钮
        levelText.text = '游戏结束：被更大的泡泡吞并或时间耗尽';
        levelActive = false;
        overlays.add('Retry');
      }
    }

    // 小点补充：当地图上小点耗尽时，每5s补充一批
    if (dotCount == 0 && started) {
      replenishAccum += dt;
      if (replenishAccum >= 5.0) {
        _spawnDots(40); // 随机补充若干
        replenishAccum = 0.0;
      }
    }

    // 定时生成道具（持续补充，限制数量上限；按关卡规则）
    if (started && levelActive) {
      // 第二关强制移除恶魔道具，确保只保留⚡
      if (currentLevel == 2) {
        for (final sh in children.whereType<ShieldItem>().toList()) {
          sh.removeFromParent();
        }
      }
      itemSpawnAccum += dt;
      if (itemSpawnAccum >= itemSpawnInterval) {
        itemSpawnAccum = 0.0;
        final shoeCount = children.whereType<ShoeItem>().length;
        final shieldCount = children.whereType<ShieldItem>().length;
        if (currentLevel >= 2 && shoeCount < maxShoeItems) {
          add(ShoeItem(position: _randomInsideWorld(offset: 60)));
        }
        if (currentLevel >= 3 && shieldCount < maxShieldItems) {
          add(ShieldItem(position: _randomInsideWorld(offset: 60)));
        }
      }
    }

    _updateCameraZoom();
  }

  Vector2 _keyboardDirection = Vector2.zero();

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent || event is KeyUpEvent) {
      final dx = (keysPressed.contains(LogicalKeyboardKey.keyD) ||
              keysPressed.contains(LogicalKeyboardKey.arrowRight))
          ? 1.0
          : (keysPressed.contains(LogicalKeyboardKey.keyA) ||
                  keysPressed.contains(LogicalKeyboardKey.arrowLeft))
              ? -1.0
              : 0.0;
      final dy = (keysPressed.contains(LogicalKeyboardKey.keyS) ||
              keysPressed.contains(LogicalKeyboardKey.arrowDown))
          ? 1.0
          : (keysPressed.contains(LogicalKeyboardKey.keyW) ||
                  keysPressed.contains(LogicalKeyboardKey.arrowUp))
              ? -1.0
              : 0.0;
      _keyboardDirection = Vector2(dx, dy);
    }
    return KeyEventResult.handled;
  }

  void _updateCameraZoom() {
    final screenW = size.x;
    // 让可视范围与屏幕大小一致
    final zoom = screenW / worldWidth;
    camera.viewfinder.zoom = zoom;
  }

  void _spawnDots(int count) {
    for (int i = 0; i < count; i++) {
      final pos = _randomInsideWorld(offset: 20);
      final dotR = 2.0 + _rng.nextDouble() * 2.0; // 2~4 半径
      final color = Colors.grey.shade700.withOpacity(0.9);
      add(Dot(radius: dotR, position: pos, color: color));
      dotCount += 1;
    }
  }

  void handleStart() {
    started = true;
    overlays.remove('Start');

    // 将地图尺寸设为当前屏幕大小
    worldWidth = size.x;
    worldHeight = size.y;

    // 重设背景与围墙尺寸/位置
    const double wallThickness = 10;
    backgroundRect.size = Vector2(worldWidth, worldHeight);

    wallTop
      ..position = Vector2(0, 0)
      ..size = Vector2(worldWidth, wallThickness);
    wallBottom
      ..position = Vector2(0, worldHeight - wallThickness)
      ..size = Vector2(worldWidth, wallThickness);
    wallLeft
      ..position = Vector2(0, 0)
      ..size = Vector2(wallThickness, worldHeight);
    wallRight
      ..position = Vector2(worldWidth - wallThickness, 0)
      ..size = Vector2(wallThickness, worldHeight);

    // 清理现有小点与道具
    for (final d in children.whereType<Dot>().toList()) {
      d.removeFromParent();
    }
    for (final s in children.whereType<ShoeItem>().toList()) {
      s.removeFromParent();
    }
    for (final sh in children.whereType<ShieldItem>().toList()) {
      sh.removeFromParent();
    }

    // 重置计数与累积
    dotCount = 0;
    replenishAccum = 0.0;

    // 置玩家到地图中心
    player
      ..position = Vector2(worldWidth / 2, worldHeight / 2)
      ..velocity = Vector2.zero();

    // 初始相机缩放与跟随
    _updateCameraZoom();
    camera.follow(player);

    // 生成基础小点；第一关不生成道具
    _spawnDots(200);

    // 开始第1关
    _startLevel(1);

    // HUD 重置
    levelText.text = '关卡: 1 | 目标：在60秒内清除所有红色NPC';
    timeText.text = '剩余: 60.0s  NPC: --';
  }

  void _startLevel(int level) {
    currentLevel = level;
    timeLeft = 60.0;
    levelActive = true;
    npcSpawnedVisible = false; // 重置，等待NPC出现
    levelText.text = '关卡: $currentLevel | 目标：在60秒内清除所有红色NPC';

    // 每关开始重置并补充深色可吃的小气泡，保证数量一致
    for (final d in children.whereType<Dot>().toList()) {
      d.removeFromParent();
    }
    dotCount = 0;
    _spawnDots(200); // 统一每关初始数量

    // 每一关重置玩家大小到初始值
    player
      ..radius = 6
      ..size = Vector2.all(12);

    // 清理现有 NPC
    for (final npc in children.whereType<NpcBubble>().toList()) {
      npc.removeFromParent();
    }
    // 清理关卡道具
    for (final s in children.whereType<ShoeItem>().toList()) {
      s.removeFromParent();
    }
    for (final sh in children.whereType<ShieldItem>().toList()) {
      sh.removeFromParent();
    }

    // 随机生成本关 NPC：第1关3个，每关+2
    final npcCount = 3 + 2 * (currentLevel - 1);
    for (int i = 0; i < npcCount; i++) {
      final pos = _randomInsideWorld(offset: 80);
      // 收紧同关NPC尺寸差异：按关卡设定基础半径+小抖动
      final baseR = (currentLevel == 1) ? 8.0 : (currentLevel == 2) ? 9.0 : 10.0;
      final jitter = (_rng.nextDouble() * 2 - 1) * 1.0; // ±1.0
      final npcR = (baseR + jitter).clamp(6.0, 12.0);
      final vel = Vector2(
        (_rng.nextDouble() * 2 - 1) * 60,
        (_rng.nextDouble() * 2 - 1) * 60,
      );
      final color = Colors.red;
      add(NpcBubble(radius: npcR, position: pos, color: color, velocity: vel));
    }

    // 按关卡生成初始道具：1无、2闪电、3闪电+恶魔
    if (currentLevel >= 2) {
      for (int i = 0; i < 6; i++) {
        add(ShoeItem(position: _randomInsideWorld(offset: 80)));
      }
    }
    if (currentLevel >= 3) {
      for (int i = 0; i < 6; i++) {
        add(ShieldItem(position: _randomInsideWorld(offset: 80)));
      }
    }
  }

  void retryLevel() {
    overlays.remove('Retry');
    timeLeft = 60.0;
    levelActive = true;
    npcSpawnedVisible = false; // 重置，等待NPC出现
    levelText.text = '关卡: $currentLevel | 目标：在60秒内清除所有红色NPC';

    // 复活玩家：如果之前被移除则重新创建并添加，否则重置状态与位置
    if (player.parent == null) {
      player = PlayerBubble(
        radius: 6,
        position: Vector2(worldWidth / 2, worldHeight / 2),
        color: Colors.blue,
      );
      add(player);
    } else {
      player.alive = true;
      player.shieldActive = false;
      player.speedMultiplier = 1.0;
      player.velocity = Vector2.zero();
      player.position = Vector2(worldWidth / 2, worldHeight / 2);
      player.radius = 6;
      player.size = Vector2.all(12);
    }
    camera.follow(player);

    // 清空当前 NPC 并重新生成本关 NPC
    for (final npc in children.whereType<NpcBubble>().toList()) {
      npc.removeFromParent();
    }
    // 清理关卡道具
    for (final s in children.whereType<ShoeItem>().toList()) {
      s.removeFromParent();
    }
    for (final sh in children.whereType<ShieldItem>().toList()) {
      sh.removeFromParent();
    }

    final npcCount = 3 + 2 * (currentLevel - 1);
    for (int i = 0; i < npcCount; i++) {
      final pos = _randomInsideWorld(offset: 80);
      // 收紧同关NPC尺寸差异：按关卡设定基础半径+小抖动
      final baseR = (currentLevel == 1) ? 8.0 : (currentLevel == 2) ? 9.0 : 10.0;
      final jitter = (_rng.nextDouble() * 2 - 1) * 1.0; // ±1.0
      final npcR = (baseR + jitter).clamp(6.0, 12.0);
      final vel = Vector2(
        (_rng.nextDouble() * 2 - 1) * 60,
        (_rng.nextDouble() * 2 - 1) * 60,
      );
      final color = Colors.red;
      add(NpcBubble(radius: npcR, position: pos, color: color, velocity: vel));
    }

    // 按关卡生成初始道具：1无、2闪电、3闪电+恶魔
    if (currentLevel >= 2) {
      for (int i = 0; i < 6; i++) {
        add(ShoeItem(position: _randomInsideWorld(offset: 80)));
      }
    }
    if (currentLevel >= 3) {
      for (int i = 0; i < 6; i++) {
        add(ShieldItem(position: _randomInsideWorld(offset: 80)));
      }
    }

    // 重置倒计时文本
    timeText.text = '剩余: 60.0s  NPC: --';
  }

  void startNextLevel() {
    overlays.remove('NextLevel');
    _startLevel(currentLevel + 1);
  }

  void showVictory() {
    levelText.text = '胜利!';
    overlays.add('Victory');
    add(ConfettiEmitter(center: Vector2(worldWidth / 2, worldHeight / 2), count: 120));
  }

  void restartGame() {
    overlays.remove('Victory');
    currentLevel = 1;
    started = true;

    for (final d in children.whereType<Dot>().toList()) {
      d.removeFromParent();
    }
    for (final npc in children.whereType<NpcBubble>().toList()) {
      npc.removeFromParent();
    }
    for (final s in children.whereType<ShoeItem>().toList()) {
      s.removeFromParent();
    }
    for (final sh in children.whereType<ShieldItem>().toList()) {
      sh.removeFromParent();
    }

    player
      ..alive = true
      ..shieldActive = false
      ..speedMultiplier = 1.0
      ..velocity = Vector2.zero()
      ..position = Vector2(worldWidth / 2, worldHeight / 2)
      ..radius = 6
      ..size = Vector2.all(12);
    camera.follow(player);

    dotCount = 0;
    replenishAccum = 0.0;
    levelText.text = '关卡: 1 | 目标：在60秒内清除所有红色NPC';
    timeText.text = '剩余: 60.0s  NPC: --';

    _spawnDots(200);
    _startLevel(1);
  }
}

class Bubble extends CircleComponent with CollisionCallbacks {
  double radius;
  Vector2 velocity;
  final Paint _paint;
  bool alive = true;
  bool shieldActive = false;
  double speedMultiplier = 1.0;
  double baseSpeed = 88.0; // 基础速度（世界单位/秒）- 提升10%

  Bubble({
    required this.radius,
    required Vector2 position,
    required Color color,
    Vector2? velocity,
  })  : velocity = velocity ?? Vector2.zero(),
        _paint = Paint()..color = color,
        super(
          position: position,
          radius: radius,
        ) {
    add(CircleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(radius, radius), radius, _paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 运动与边界反弹
    position += velocity * dt;
    _keepInsideWorldAndBounce();
  }

  void _keepInsideWorldAndBounce() {
    if (position.x - radius < 0) {
      position.x = radius;
      velocity.x = velocity.x.abs();
    }
    if (position.y - radius < 0) {
      position.y = radius;
      velocity.y = velocity.y.abs();
    }
    if (position.x + radius > worldWidth) {
      position.x = worldWidth - radius;
      velocity.x = -velocity.x.abs();
    }
    if (position.y + radius > worldHeight) {
      position.y = worldHeight - radius;
      velocity.y = -velocity.y.abs();
    }
  }

  void consumeByArea(double otherArea) {
    final currentArea = pi * radius * radius;
    final newArea = currentArea + otherArea;
    final newRadius = sqrt(newArea / pi);
    _animateToRadius(newRadius);
  }

  void _animateToRadius(double newRadius) {
    final currentSize = size.clone();
    final targetSize = Vector2.all(newRadius * 2);
    add(SequenceEffect([
      SizeEffect.to(currentSize * 1.12, EffectController(duration: 0.12, curve: Curves.easeOut)),
      SizeEffect.to(targetSize, EffectController(duration: 0.18, curve: Curves.easeInOut)),
    ]));
    radius = newRadius;
  }
}

class PlayerBubble extends Bubble with HasGameRef<BubbleGame> {
  Vector2 controlInput = Vector2.zero();
  double effectTimerSpeed = 0.0;
  double effectTimerShield = 0.0;

  PlayerBubble({
    required super.radius,
    required super.position,
    required Color color,
  }) : super(color: color);

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);

    if (other is Dot && other.alive) {
      other.alive = false;
      other.removeFromParent();
      consumeByArea(pi * other.radius * other.radius);
      // 更新小点计数
      if (gameRef is BubbleGame) {
        (gameRef as BubbleGame).dotCount -= 1;
      }
      return;
    }

    if (other is ShoeItem && other.alive) {
      other.alive = false;
      other.removeFromParent();
      speedMultiplier = 2.5; // 加速150%
      effectTimerSpeed = 5.0;
      return;
    }

    if (other is ShieldItem && other.alive) {
      other.alive = false;
      other.removeFromParent();
      shieldActive = true;
      effectTimerShield = 5.0;
      return;
    }

    if (other is Bubble && other.alive) {
      final myR = radius;
      final otherR = other.radius;
      if (shieldActive || myR > otherR) {
        other.alive = false;
        other.removeFromParent();
        consumeByArea(pi * otherR * otherR);
      } else if (other is NpcBubble && otherR > myR) {
        // 被更大的 NPC 吞并：游戏结束
        (gameRef as BubbleGame).levelText.text = '游戏结束';
        (gameRef as BubbleGame).levelActive = false;
        (gameRef as BubbleGame).overlays.add('Retry');
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 控制输入 -> 速度
    final dir = controlInput.normalized();
    velocity = dir * baseSpeed * speedMultiplier;

    // 道具计时衰减
    if (effectTimerSpeed > 0) {
      effectTimerSpeed -= dt;
      if (effectTimerSpeed <= 0) {
        speedMultiplier = 1.0;
      }
    }
    if (effectTimerShield > 0) {
      effectTimerShield -= dt;
      if (effectTimerShield <= 0) {
        shieldActive = false;
      }
    }
  }

  @override
  void consumeByArea(double otherArea) {
    final currentArea = pi * radius * radius;
    final newArea = currentArea + otherArea;
    final newRadius = sqrt(newArea / pi);
    final delta = newRadius - radius;
    (gameRef as BubbleGame).add(GrowthText('+${delta.toStringAsFixed(1)}', position + Vector2(0, -radius - 6)));
    _animateToRadius(newRadius);
  }
}

class NpcBubble extends Bubble with HasGameRef<BubbleGame> {
  NpcBubble({
    required super.radius,
    required super.position,
    required Color color,
    required super.velocity,
  }) : super(color: color);

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (!alive) return;

    if (other is Dot && other.alive) {
      other.alive = false;
      other.removeFromParent();
      consumeByArea(pi * other.radius * other.radius);
      // 更新小点计数
      if (gameRef is BubbleGame) {
        (gameRef as BubbleGame).dotCount -= 1;
      }
      return;
    }

    if (other is Bubble && other.alive) {
      if (radius > other.radius && !(other is PlayerBubble && other.shieldActive)) {
        other.alive = false;
        other.removeFromParent();
        consumeByArea(pi * other.radius * other.radius);
        // 如果被吃的是玩家，则判定游戏结束并弹出失败弹窗
        if (other is PlayerBubble) {
          (gameRef as BubbleGame).levelText.text = '游戏结束';
          (gameRef as BubbleGame).levelActive = false;
          (gameRef as BubbleGame).overlays.add('Retry');
        }
      }
    }
  }
}

class Dot extends CircleComponent with CollisionCallbacks, HasGameRef<BubbleGame> {
  double radius;
  bool alive = true;
  final Paint _paint;

  Dot({
    required this.radius,
    required Vector2 position,
    required Color color,
  })  : _paint = Paint()..color = color,
        super(position: position, radius: radius) {
    add(CircleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(radius, radius), radius, _paint);
  }
}

class EmojiItem extends PositionComponent with CollisionCallbacks {
  bool alive = true;
  final String emoji;
  late Vector2 velocity;
  EmojiItem({required this.emoji, required Vector2 position})
      : super(position: position, size: Vector2(22, 22)) {
    add(RectangleHitbox());
    final tc = TextComponent(
      text: emoji,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
      priority: 1,
    );
    tc.textRenderer = TextPaint(
      style: const TextStyle(
        fontSize: 20,
        fontFamilyFallback: [
          'Apple Color Emoji',
          'Segoe UI Emoji',
          'Noto Color Emoji',
          'Noto Emoji',
          'EmojiSymbols',
          'sans-serif',
        ],
      ),
    );
    add(tc);
    final rnd = Random();
    velocity = Vector2(
      (rnd.nextDouble() * 2 - 1) * 70,
      (rnd.nextDouble() * 2 - 1) * 70,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!alive) return;
    position += velocity * dt;
    if (position.x < 0) {
      position.x = 0;
      velocity.x = velocity.x.abs();
    }
    if (position.y < 0) {
      position.y = 0;
      velocity.y = velocity.y.abs();
    }
    if (position.x + size.x > worldWidth) {
      position.x = worldWidth - size.x;
      velocity.x = -velocity.x.abs();
    }
    if (position.y + size.y > worldHeight) {
      position.y = worldHeight - size.y;
      velocity.y = -velocity.y.abs();
    }
  }
}

class ShoeItem extends EmojiItem {
  ShoeItem({required Vector2 position}) : super(emoji: '⚡', position: position);
}

class ShieldItem extends EmojiItem {
  ShieldItem({required Vector2 position}) : super(emoji: '😈', position: position);
}

  Future<Sprite> _makeShoeSprite() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const sz = Size(32, 32);
    final paint = Paint()..color = Colors.deepOrange;
    // 鞋底
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(6, 18, 20, 8), const Radius.circular(4)), paint);
    // 鞋面
    canvas.drawPath(
      Path()
        ..moveTo(8, 18)
        ..lineTo(18, 10)
        ..lineTo(26, 14)
        ..lineTo(24, 20)
        ..close(),
      paint..color = Colors.orange,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(sz.width.toInt(), sz.height.toInt());
    return Sprite(image);
  }

  Future<Sprite> _makeShieldSprite() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const sz = Size(32, 32);
    final paint = Paint()..color = Colors.purple;
    // 盾牌底
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(6, 6, 20, 24), const Radius.circular(6)), paint);
    // 十字装饰
    final p2 = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(16, 10), const Offset(16, 26), p2);
    canvas.drawLine(const Offset(10, 18), const Offset(22, 18), p2);
    final picture = recorder.endRecording();
    final image = await picture.toImage(sz.width.toInt(), sz.height.toInt());
    return Sprite(image);
  }

class GrowthText extends TextComponent {
  double life = 0.8;
  GrowthText(String txt, Vector2 worldPos)
      : super(text: txt, position: worldPos, anchor: Anchor.center, priority: 1000) {
    textRenderer = TextPaint(
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.green,
        shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    position += Vector2(0, -30) * dt;
    final opacity = life.clamp(0.0, 0.8) / 0.8;
    textRenderer = TextPaint(
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.green.withOpacity(opacity),
        shadows: const [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
      ),
    );
    if (life <= 0) {
      removeFromParent();
    }
  }
}

class ConfettiPiece extends PositionComponent {
  final Paint _paint;
  Vector2 velocity;
  double angularVelocity;
  double gravity = 200.0;
  double life = 2.5;

  ConfettiPiece({required Vector2 position, required Color color})
      : _paint = Paint()..color = color,
        velocity = Vector2(
          (Random().nextDouble() * 2 - 1) * 160,
          -(80 + Random().nextDouble() * 140),
        ),
        angularVelocity = (Random().nextDouble() * 2 - 1) * 6,
        super(position: position, size: Vector2(6 + Random().nextDouble() * 4, 3 + Random().nextDouble() * 2), anchor: Anchor.center) {
    priority = 2000;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    canvas.save();
    canvas.translate(0, 0);
    canvas.rotate(angle);
    canvas.drawRect(rect, _paint);
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
    velocity.y += gravity * dt;
    angle += angularVelocity * dt;
    life -= dt;
    if (life <= 0) {
      removeFromParent();
    }
  }
}

class ConfettiEmitter extends Component with HasGameRef<BubbleGame> {
  final Vector2 center;
  final int count;
  ConfettiEmitter({required this.center, this.count = 100});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    final colors = [
      Colors.pinkAccent,
      Colors.amber,
      Colors.lightGreen,
      Colors.cyan,
      Colors.deepPurpleAccent,
      Colors.orange,
    ];
    for (int i = 0; i < count; i++) {
      final jitter = Vector2(
        (Random().nextDouble() * 2 - 1) * 60,
        (Random().nextDouble() * 2 - 1) * 40,
      );
      final pos = center + jitter;
      final color = colors[Random().nextInt(colors.length)];
      gameRef.add(ConfettiPiece(position: pos, color: color));
    }
    // 自动移除发射器
    add(TimerComponent(period: 3.0, onTick: () {
      removeFromParent();
    }));
  }
}