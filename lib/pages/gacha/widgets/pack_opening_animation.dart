import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/pack_model.dart';
import '../../../viewmodels/gacha_view_model.dart';
import 'gacha_utils.dart';
import 'pack_card.dart';

typedef VoidCallback = void Function();

class PackOpeningAnimation extends StatefulWidget {
  final GachaViewModel viewModel;
  final Animation<double> animation;
  final VoidCallback onPackSwiped;
  final VoidCallback playPackOpenSound;

  const PackOpeningAnimation({
    Key? key,
    required this.viewModel,
    required this.animation,
    required this.onPackSwiped,
    required this.playPackOpenSound,
  }) : super(key: key);

  @override
  State<PackOpeningAnimation> createState() => _PackOpeningAnimationState();
}

class _PackOpeningAnimationState extends State<PackOpeningAnimation> {
  // スワイプのプレビュー用の変数
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final selectedPack =
        widget.viewModel.packs[widget.viewModel.selectedPackIndex];
    final rarityLevel = selectedPack.rarityLevel;

    final List<Color> bgColors = GachaUtils.getBackgroundColors(rarityLevel);
    final Color glowColor = GachaUtils.getGlowColor(rarityLevel);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final value = widget.animation.value;

        // アニメーションの進行が0の場合は常にスワイプ待ちの初期状態を表示
        if (value == 0.0 || value < 0.3) {
          return _buildInitialPackState(selectedPack, glowColor);
        }
        // パックが開いて中身が見える演出
        else if (value < 0.6) {
          return _buildOpeningPackState(
            value,
            bgColors,
            glowColor,
            selectedPack,
          );
        }
        // カードが現れる最終演出
        else {
          return _buildCardRevealState(value, bgColors, glowColor, rarityLevel);
        }
      },
    );
  }

  // 初期状態（スワイプを待つ）
  Widget _buildInitialPackState(PackModel selectedPack, Color glowColor) {
    return GestureDetector(
      // 横方向のドラッグを検出し、ドラッグの動きに合わせてアニメーションを事前表示
      onHorizontalDragStart: (details) {
        setState(() {
          _isDragging = true;
          _dragOffset = 0.0;
        });
      },
      onHorizontalDragUpdate: (details) {
        // ドラッグ中のプレビューアニメーション
        setState(() {
          _dragOffset += details.delta.dx;
          // ドラッグ量を制限
          _dragOffset = _dragOffset.clamp(-50.0, 50.0);
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          _isDragging = false;
          _dragOffset = 0.0;
        });

        if (details.primaryVelocity != null) {
          // スワイプ速度がしきい値を超えたら開封アニメーションを開始
          if (details.primaryVelocity!.abs() > 300) {
            // スライス効果の触覚フィードバック
            HapticFeedback.mediumImpact();
            widget.onPackSwiped();
            widget.playPackOpenSound();
          }
        }
      },
      // タップでも開封可能に
      onTap: () {
        widget.onPackSwiped();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // パックカードを表示（ドラッグ中は少し傾ける）
              Transform(
                alignment: Alignment.center,
                transform:
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // パースペクティブ効果
                      ..rotateY(_dragOffset / 500), // ドラッグに応じて少し回転
                child: PackCard(
                  packData: selectedPack,
                  isSelected: true,
                  scale: 1.2,
                  onTap: null,
                ),
              ),

              // スライスラインのインジケーター（スワイプを促すヒント）
              Positioned(
                child: Container(
                  width: 150,
                  height: 4,
                  decoration: BoxDecoration(
                    // 点線のようなエフェクト
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        glowColor.withOpacity(0.8),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    // 明滅エフェクト
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(
                          0.5 *
                              (0.5 +
                                  0.5 *
                                      sin(
                                        DateTime.now().millisecondsSinceEpoch /
                                            500,
                                      )),
                        ),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // パックの右端が光る演出
              Positioned(
                right: 0,
                child: Container(
                  width: 20,
                  height: 280 * 1.2, // パックの高さに合わせる
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        glowColor.withOpacity(
                          0.8 *
                              (0.5 +
                                  0.5 *
                                      sin(
                                        DateTime.now().millisecondsSinceEpoch /
                                            300,
                                      )),
                        ), // 明滅エフェクト
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 左右のスワイプアイコン表示（ドラッグ方向に応じて強調）
              Positioned(
                right: -15,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: glowColor.withOpacity(_dragOffset < 0 ? 1.0 : 0.7),
                  size: _dragOffset < 0 ? 45 : 40,
                ),
              ),
              Positioned(
                left: -15,
                child: Icon(
                  Icons.arrow_back_ios,
                  color: glowColor.withOpacity(_dragOffset > 0 ? 1.0 : 0.7),
                  size: _dragOffset > 0 ? 45 : 40,
                ),
              ),

              // ドラッグ中のスライス予告エフェクト
              if (_isDragging && _dragOffset.abs() > 20)
                Positioned(
                  child: Container(
                    width: 180,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        (_dragOffset.abs() - 20) / 30 * 0.7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withOpacity(
                            (_dragOffset.abs() - 20) / 30 * 0.8,
                          ),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          Text(
            '← スワイプしてパックを開ける →',
            style: TextStyle(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // パックが開いていく状態
  Widget _buildOpeningPackState(
    double value,
    List<Color> bgColors,
    Color glowColor,
    PackModel selectedPack,
  ) {
    final openingProgress = (value - 0.3) / 0.3; // 0.3~0.6を0~1にマッピング
    final clampedOpeningProgress = max(
      0.0,
      min(1.0, openingProgress),
    ); // 安全な範囲に制限

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bgColors, // レア度に応じた背景色
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 光るエフェクト（レア度が高いほど強い）
            Container(
              width: 250 + clampedOpeningProgress * 100,
              height: 330 + clampedOpeningProgress * 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withOpacity(0.8),
                    glowColor.withOpacity(0.0),
                  ],
                  radius: 0.5,
                ),
              ),
            ),

            // パックが切り裂かれるアニメーション - スライス効果
            // 上半分のパック
            Positioned(
              top: -20 - clampedOpeningProgress * 120,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform:
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(-clampedOpeningProgress * 0.5), // 上半分が少し開く
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.5,
                    child: Container(
                      width: 220,
                      height: 300,
                      decoration: BoxDecoration(
                        color: selectedPack.color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(0.5),
                            spreadRadius: 3,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.catching_pokemon,
                          size: 120,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 下半分のパック
            Positioned(
              bottom: -20 - clampedOpeningProgress * 120,
              child: Transform(
                alignment: Alignment.topCenter,
                transform:
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(clampedOpeningProgress * 0.5), // 下半分が少し開く
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 0.5,
                    child: Container(
                      width: 220,
                      height: 300,
                      decoration: BoxDecoration(
                        color: selectedPack.color,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(0.5),
                            spreadRadius: 3,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // スライス効果のアニメーション（白い線と輝き）
            if (clampedOpeningProgress > 0.1 && clampedOpeningProgress < 0.6)
              Positioned(
                child: Container(
                  width: 240,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(
                          0.8 * sin(clampedOpeningProgress * pi),
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(
                          0.6 * sin(clampedOpeningProgress * pi),
                        ),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),

            // キラキラ光るパーティクル効果（パックが開くときに散る）
            if (clampedOpeningProgress > 0.3) ...[
              for (int i = 0; i < 10; i++)
                Positioned(
                  left:
                      100 +
                      cos(i * pi / 5) *
                          (100 + 150 * (clampedOpeningProgress - 0.3)),
                  top:
                      150 +
                      sin(i * pi / 5) *
                          (50 + 120 * (clampedOpeningProgress - 0.3)),
                  child: Opacity(
                    opacity: max(
                      0.0,
                      1.0 - (clampedOpeningProgress - 0.3) * 1.5,
                    ),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],

            // 開封中に内部からこぼれる光（徐々に強くなる）
            if (clampedOpeningProgress > 0.2)
              Positioned(
                child: Container(
                  width: 150 * (clampedOpeningProgress - 0.2) * 3,
                  height: 30 + 50 * (clampedOpeningProgress - 0.2) * 2,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        glowColor.withOpacity(0.7 * clampedOpeningProgress),
                        Colors.transparent,
                      ],
                      radius: 0.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // カードが現れる状態 - 既存の実装を維持
  Widget _buildCardRevealState(
    double value,
    List<Color> bgColors,
    Color glowColor,
    int rarityLevel,
  ) {
    final cardRevealProgress = (value - 0.6) / 0.4; // 0.6~1.0を0~1にマッピング
    final clampedCardRevealProgress = max(
      0.0,
      min(1.0, cardRevealProgress),
    ); // 安全な範囲に制限

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bgColors, // レア度に応じた背景色
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 光のエフェクト（拡大して消える）
            Container(
              width: 300 + clampedCardRevealProgress * 200,
              height: 400 + clampedCardRevealProgress * 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withOpacity(
                      max(
                        0.0,
                        min(1.0, 0.7 * (1.0 - clampedCardRevealProgress)),
                      ),
                    ),
                    Colors.transparent,
                  ],
                  radius: 0.5,
                ),
              ),
            ),

            // クラッカーのようなパーティクルエフェクト（高レアの場合）
            if (rarityLevel >= 3)
              ...List.generate(20, (index) {
                final angle = index * pi / 10;
                final distance = 150 + clampedCardRevealProgress * 100;
                return Positioned(
                  left: 150 + cos(angle) * distance * clampedCardRevealProgress,
                  top: 150 + sin(angle) * distance * clampedCardRevealProgress,
                  child: Opacity(
                    opacity: max(
                      0.0,
                      min(1.0, 1.0 - clampedCardRevealProgress * 0.8),
                    ),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: glowColor,
                      ),
                    ),
                  ),
                );
              }),

            // カード
            Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(pi * (1.0 - clampedCardRevealProgress)),
              child: Container(
                width: 220,
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: GachaUtils.getCardGradient(rarityLevel),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.5),
                      spreadRadius: 3,
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.catching_pokemon,
                        size: 100,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        GachaUtils.getRarityText(rarityLevel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        GachaUtils.getRarityStars(rarityLevel),
                        style: TextStyle(
                          color: GachaUtils.getRarityStarColor(rarityLevel),
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
