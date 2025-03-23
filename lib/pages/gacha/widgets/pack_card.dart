import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../models/pack_model.dart';

typedef SwipeDirectionCallback = void Function(SwipeDirection direction);

// スワイプ方向を示す列挙型
enum SwipeDirection { left, right }

class PackCard extends StatefulWidget {
  final PackModel packData;
  final bool isSelected;
  final VoidCallback? onTap;
  final double scale;
  final double rotation;
  // 新規追加: スワイプ検出時のコールバック
  final SwipeDirectionCallback? onSwipe;

  const PackCard({
    Key? key,
    required this.packData,
    required this.isSelected,
    this.onTap,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.onSwipe,
  }) : super(key: key);

  @override
  State<PackCard> createState() => _PackCardState();
}

class _PackCardState extends State<PackCard> {
  // スワイプ関連の変数
  double _dragStartX = 0.0;
  double _dragCurrentX = 0.0;
  bool _isDragging = false;
  static const double _swipeThreshold = 20.0; // スワイプ判定のしきい値

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      // 新規追加: 水平スワイプの検出
      onHorizontalDragStart: (details) {
        if (widget.onSwipe != null) {
          setState(() {
            _isDragging = true;
            _dragStartX = details.globalPosition.dx;
            _dragCurrentX = _dragStartX;
          });
        }
      },
      onHorizontalDragUpdate: (details) {
        if (widget.onSwipe != null && _isDragging) {
          setState(() {
            _dragCurrentX = details.globalPosition.dx;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (widget.onSwipe != null && _isDragging) {
          final dragDifference = _dragCurrentX - _dragStartX;
          if (dragDifference.abs() > _swipeThreshold) {
            // しきい値を超えたらスワイプとして処理
            if (dragDifference > 0) {
              widget.onSwipe!(SwipeDirection.right);
            } else {
              widget.onSwipe!(SwipeDirection.left);
            }
          }
          setState(() {
            _isDragging = false;
          });
        }
      },
      child: Transform(
        transform:
            Matrix4.identity()
              ..setEntry(3, 2, 0.001) // パースペクティブ効果
              ..rotateX(0.05) // X軸で少し傾ける
              ..scale(widget.scale), // スケール変更（引数から）
        // Y軸回転を削除 - 常に正面を向くように
        alignment: Alignment.center,
        child: Container(
          width: 150,
          height: 210,
          decoration: BoxDecoration(
            // 統一されたデザインベース
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.packData.color.withOpacity(0.9),
                widget.packData.color,
                widget.packData.color.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              // 3D効果のための複数の影
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(4, 6),
                blurRadius: 10,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                offset: const Offset(-2, -2),
                blurRadius: 5,
                spreadRadius: 0,
              ),
            ],
            // 選択時の外枠
            border:
                widget.isSelected
                    ? Border.all(color: Colors.yellow.shade300, width: 3)
                    : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                // カードの内側のグラデーション（3D効果）
                Positioned.fill(
                  child: CustomPaint(
                    painter: CardGradientPainter(widget.packData.color),
                  ),
                ),

                // スワイプ中の場合、スワイプ方向を示す視覚的なヒントを表示
                if (_isDragging && (_dragCurrentX - _dragStartX).abs() > 10)
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 左へのスワイプヒント
                        if (_dragCurrentX < _dragStartX)
                          Container(
                            width: 25,
                            color: Colors.white.withOpacity(0.3),
                            child: Center(
                              child: Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                                size:
                                    20 *
                                    math.min(
                                      1.0,
                                      (_dragStartX - _dragCurrentX) / 50,
                                    ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 25),

                        // 右へのスワイプヒント
                        if (_dragCurrentX > _dragStartX)
                          Container(
                            width: 25,
                            color: Colors.white.withOpacity(0.3),
                            child: Center(
                              child: Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size:
                                    20 *
                                    math.min(
                                      1.0,
                                      (_dragCurrentX - _dragStartX) / 50,
                                    ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 25),
                      ],
                    ),
                  ),

                // 上部のタイトルバー
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: widget.packData.color.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SIKAPOKE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),

                // 中央のアイコン部分 - 幾何学的なデザイン
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 5,
                            spreadRadius: 1,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: GeometricPatternPainter(
                          baseColor: widget.packData.color,
                          rarityLevel: widget.packData.rarityLevel,
                        ),
                      ),
                    ),
                  ),
                ),

                // 下部のラベル - パック名
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: widget.packData.color.withOpacity(0.8),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, -2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.packData.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                // 選択中のカードに光るエフェクト
                if (widget.isSelected) _buildGlowEffect(),

                // キラキラ光のエフェクト
                ..._buildSparkles(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 光るエフェクト（選択時の輝き）
  Widget _buildGlowEffect() {
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.srcATop,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // キラキラ光る小さな点を追加
  List<Widget> _buildSparkles() {
    final random = math.Random(widget.packData.hashCode);
    final sparkleCount = 3 + random.nextInt(3);

    return List.generate(sparkleCount, (index) {
      final size = 3.0 + random.nextDouble() * 3.0;

      return Positioned(
        left: random.nextDouble() * 150,
        top: random.nextDouble() * 210,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 3,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    });
  }
}

// カードの3Dグラデーション効果を描画するカスタムペインター
class CardGradientPainter extends CustomPainter {
  final Color baseColor;

  CardGradientPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // メインのグラデーション（3D効果用）
    final mainGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.4),
        baseColor.withOpacity(0.1),
        Colors.black.withOpacity(0.2),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    // 左上から右下へのハイライト効果
    final highlightGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.0)],
      stops: const [0.0, 0.3],
    );

    // グラデーションを描画
    canvas.drawRect(rect, Paint()..shader = mainGradient.createShader(rect));

    // 左上の小さい四角形にハイライトを描画
    final highlightRect = Rect.fromLTWH(
      0,
      0,
      size.width * 0.4,
      size.height * 0.4,
    );
    canvas.drawRect(
      highlightRect,
      Paint()..shader = highlightGradient.createShader(highlightRect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 幾何学的パターンを描画するカスタムペインター
class GeometricPatternPainter extends CustomPainter {
  final Color baseColor;
  final int rarityLevel;

  GeometricPatternPainter({required this.baseColor, required this.rarityLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = baseColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    final fillPaint =
        Paint()
          ..color = baseColor.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // レベルに応じたパターンの複雑さ
    final complexity = rarityLevel;

    // 幾何学的なパターンを描画

    // 1. 中央の形
    switch (complexity) {
      case 1: // シンプルな四角形
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.5,
            height: size.height * 0.5,
          ),
          paint,
        );
        break;

      case 2: // 二重の四角形
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.6,
            height: size.height * 0.6,
          ),
          paint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.4,
            height: size.height * 0.4,
          ),
          paint,
        );
        break;

      case 3: // 三角形と四角形
        final path = Path();
        path.moveTo(centerX, centerY - size.height * 0.3);
        path.lineTo(centerX + size.width * 0.3, centerY + size.height * 0.3);
        path.lineTo(centerX - size.width * 0.3, centerY + size.height * 0.3);
        path.close();
        canvas.drawPath(path, paint);

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.3,
            height: size.height * 0.3,
          ),
          paint,
        );
        break;

      case 4: // 複雑な六角形
        final radius = size.width * 0.35;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          final x = centerX + radius * math.cos(angle);
          final y = centerY + radius * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);

        // 内側の三角形
        final innerPath = Path();
        for (int i = 0; i < 3; i++) {
          final angle = i * 2 * math.pi / 3;
          final x = centerX + radius * 0.5 * math.cos(angle);
          final y = centerY + radius * 0.5 * math.sin(angle);

          if (i == 0) {
            innerPath.moveTo(x, y);
          } else {
            innerPath.lineTo(x, y);
          }
        }
        innerPath.close();
        canvas.drawPath(innerPath, paint);
        break;

      default: // デフォルトは単純な四角形
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(centerX, centerY),
            width: size.width * 0.5,
            height: size.height * 0.5,
          ),
          paint,
        );
    }

    // 2. 装飾パターン
    // レア度に応じて細かい装飾を追加
    for (int i = 0; i < complexity; i++) {
      // 周辺の円
      final radius = size.width * (0.15 + i * 0.05);
      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        Paint()
          ..color = baseColor.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // 3. 対角線
    if (complexity >= 3) {
      canvas.drawLine(
        Offset(size.width * 0.2, size.height * 0.2),
        Offset(size.width * 0.8, size.height * 0.8),
        Paint()
          ..color = baseColor.withOpacity(0.4)
          ..strokeWidth = 1.0,
      );
      canvas.drawLine(
        Offset(size.width * 0.8, size.height * 0.2),
        Offset(size.width * 0.2, size.height * 0.8),
        Paint()
          ..color = baseColor.withOpacity(0.4)
          ..strokeWidth = 1.0,
      );
    }

    // 4. 中央の点
    canvas.drawCircle(
      Offset(centerX, centerY),
      3.0,
      Paint()
        ..color = baseColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
