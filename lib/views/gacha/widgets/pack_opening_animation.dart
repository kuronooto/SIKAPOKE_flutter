import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/pack_model.dart';
import '../../../view_models/gacha_view_model.dart';
import 'gacha_utils.dart';
import 'pack_card.dart';

typedef VoidCallback = void Function();

class PackOpeningAnimation extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final selectedPack = viewModel.packs[viewModel.selectedPackIndex];
    final rarityLevel = selectedPack.rarityLevel;

    final List<Color> bgColors = GachaUtils.getBackgroundColors(rarityLevel);
    final Color glowColor = GachaUtils.getGlowColor(rarityLevel);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;

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
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity!.abs() > 300) {
            // 速いスワイプでアニメーションを加速
            onPackSwiped();
            playPackOpenSound();
          }
        }
      },
      onTap: () {
        // タップでもアニメーションを進める（ユーザーの好みに合わせて）
        onPackSwiped();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // パック
              PackCard(
                packData: selectedPack,
                isSelected: true,
                scale: 1.2,
                onTap: null,
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

              // スワイプアイコン
              Positioned(
                right: -15,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: glowColor,
                  size: 40,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
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

            // パックが開く演出
            Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(pi * clampedOpeningProgress),
              child: Container(
                width: 220,
                height: 300,
                decoration: BoxDecoration(
                  color: selectedPack.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.catching_pokemon,
                    size: 120,
                    color: Colors.white.withOpacity(
                      max(0.0, min(1.0, 1.0 - clampedOpeningProgress)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // カードが現れる状態
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
