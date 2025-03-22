import 'dart:math';
import 'package:flutter/material.dart';
import '../../../view_models/gacha_view_model.dart';
import 'gacha_utils.dart';
import 'pack_card.dart';

typedef SelectPackFunction = void Function(int index);

class PackSelectionWidget extends StatefulWidget {
  final GachaViewModel viewModel;
  final SelectPackFunction onPackSelected;
  final VoidCallback playSelectSound;

  const PackSelectionWidget({
    Key? key,
    required this.viewModel,
    required this.onPackSelected,
    required this.playSelectSound,
  }) : super(key: key);

  @override
  State<PackSelectionWidget> createState() => _PackSelectionWidgetState();
}

class _PackSelectionWidgetState extends State<PackSelectionWidget>
    with TickerProviderStateMixin {
  // 3D回転のための変数
  double _rotationAngle = 0.0; // 全体の回転角度
  double _lastPanX = 0.0; // 前回のタッチ位置X
  double _lastPanY = 0.0; // 前回のタッチ位置Y
  double _rotationVelocity = 0.0; // 回転速度
  bool _isDragging = false; // ドラッグ中フラグ

  // アニメーション用コントローラ
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    // 3D回転アニメーション用コントローラ
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10), // 長めの持続時間
      vsync: this,
    )..addListener(() {
      if (_rotationVelocity != 0 && !_isDragging) {
        setState(() {
          // 慣性による回転
          _rotationAngle += _rotationVelocity;
          // 減速
          _rotationVelocity *= 0.98;

          // 速度が小さくなったら停止
          if (_rotationVelocity.abs() < 0.001) {
            _rotationVelocity = 0;
            _rotationController.stop();
          }
        });
      }
    });
    _rotationController.repeat(); // 常に更新
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // パックを3D空間の円周上に配置し、横方向に回転するように表示

    final int packCount = widget.viewModel.packs.length;
    if (packCount == 0) return const SizedBox.shrink(); // パックがない場合は何も表示しない

    // 選択インデックスが無効な場合は0に設定
    if (widget.viewModel.selectedPackIndex < 0 ||
        widget.viewModel.selectedPackIndex >= packCount) {
      // 範囲外の場合は最初のパックを選択
      widget.viewModel.selectPack(0);
    }

    final double radius =
        MediaQuery.of(context).size.width * 0.4; // 円の半径を大きくして横回転感を強調
    final double centerY =
        MediaQuery.of(context).size.height * 0.35; // 中心位置のY座標

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景のグラデーション
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.shade100.withOpacity(0.7),
                      Colors.blue.shade100.withOpacity(0.3),
                    ],
                    radius: 0.7,
                  ),
                ),
              ),

              // 円形の軌道を示す半透明の円（横から見た楕円）
              Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height:
                    MediaQuery.of(context).size.width * 0.3, // 縦に潰して円が横から見える感じに
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(
                    MediaQuery.of(context).size.width * 0.15,
                  ),
                  border: Border.all(
                    color: Colors.deepPurple.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),

              // 横回転を検出する透明なコントロール
              GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _isDragging = true;
                    _lastPanX = details.globalPosition.dx;
                    _lastPanY = details.globalPosition.dy;
                    _rotationVelocity = 0;
                  });

                  if (!_rotationController.isAnimating) {
                    _rotationController.repeat();
                  }
                },
                onPanUpdate: (details) {
                  if (widget.viewModel.isSelecting) return;

                  final currentX = details.globalPosition.dx;
                  final currentY = details.globalPosition.dy;

                  final dx = currentX - _lastPanX;

                  final rotationDelta = dx / 100 * -0.15; // 左右の回転方向と速度調整

                  setState(() {
                    _rotationAngle += rotationDelta;
                    _rotationVelocity = rotationDelta * 2;
                    _lastPanX = currentX;
                    _lastPanY = currentY;

                    _updateSelectedPackFromRotation();
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    _isDragging = false;

                    final velocity = details.velocity.pixelsPerSecond;
                    final speed = velocity.distance;
                    if (speed > 100) {
                      final direction = velocity.dx > 0 ? -1.0 : 1.0; // 回転方向を反転
                      _rotationVelocity =
                          direction * min(speed / 1000, 0.2); // 速度上限を上げて回転感を強調
                    }
                  });

                  // パンが終了したら、選択中のパックが正面に来るようにアニメーション
                  _snapToSelectedPack();
                },
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                ),
              ),

              // 全てのパックを円周上に配置
              ...List.generate(packCount, (index) {
                // 各パックの角度を計算
                final indexDiff =
                    (index - widget.viewModel.selectedPackIndex) % packCount;
                final angle = (2 * pi * indexDiff / packCount) + _rotationAngle;

                // 3D位置の計算（横回転を表現）
                final x = sin(angle) * radius; // x座標はsin(angle)で計算（横回転）
                final z = cos(angle) * radius; // z座標はcos(angle)で計算（横回転）
                final scale = GachaUtils.map(
                  z,
                  -radius,
                  radius,
                  0.6,
                  1.2,
                ); // スケール差を大きくして立体感を強調

                // 横回転に見せるために、奥行きに応じてY座標をわずかに調整
                final yOffset = -GachaUtils.map(z, -radius, radius, -10, 10);

                // Z座標に応じた不透明度（奥のパックは少し透明に）
                final opacity = GachaUtils.map(z, -radius, radius, 0.5, 1.0);

                // 選択中かどうか
                final isSelected = index == widget.viewModel.selectedPackIndex;

                // 正面にあるか（選択中でなくても正面に来る場合がある）
                final isInFront = z > radius * 0.7;

                // 重なり順を制御するためのZIndex（奥のパックから描画）
                final zIndex = 1000 - z.round();

                return Positioned(
                  left: MediaQuery.of(context).size.width / 2 + x - 75,
                  top: centerY + yOffset,
                  child: Transform(
                    transform:
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // パースペクティブ
                          ..scale(scale), // Z軸に応じたスケール
                    // パックの回転を削除して常に正面を向くように修正
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: opacity,
                      child: Stack(
                        children: [
                          // パックカード
                          GestureDetector(
                            onTap:
                                widget.viewModel.isSelecting
                                    ? null
                                    : () => _animateToPackIndex(index),
                            child: PackCard(
                              packData: widget.viewModel.packs[index],
                              isSelected: isSelected, // 正面判定を削除
                              scale: 1.0,
                              rotation: 0.0,
                              onTap: null,
                            ),
                          ),

                          // 選択中のパックにバッジを表示（正面判定を削除）
                          if (isSelected)
                            Positioned(
                              bottom: -25,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.shade600,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        spreadRadius: 1,
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    '選択中',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // 正面位置を示す半透明のフレーム
              Positioned(
                left: MediaQuery.of(context).size.width / 2 - 80,
                top: centerY - 105,
                child: Container(
                  width: 160,
                  height: 224,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // 選択中のパックが正面にある場合、ハイライト効果を追加
              if (_isSelectedPackInFront())
                Positioned(
                  left: MediaQuery.of(context).size.width / 2 - 80,
                  top: centerY - 105,
                  child: Container(
                    width: 160,
                    height: 224,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.withOpacity(0.3),
                          spreadRadius: 5,
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isSelectedPackInFront() {
    if (widget.viewModel.selectedPackIndex < 0 ||
        widget.viewModel.packs.isEmpty)
      return false;

    // 選択中のパックの角度
    final angle = _rotationAngle;

    // 正面判定（Z軸が正の値で、かつある程度大きい場合）
    return angle.abs() < 0.3; // 正面の許容範囲
  }

  // 回転角度から選択中のパックインデックスを更新
  void _updateSelectedPackFromRotation() {
    final packCount = widget.viewModel.packs.length;
    if (packCount == 0) return;

    // 回転角度に基づいて、どのパックが最も正面に近いかを計算
    double minAngleDiff = double.infinity;
    int closestIndex = widget.viewModel.selectedPackIndex;

    for (int i = 0; i < packCount; i++) {
      // 各パックの角度を計算（選択中パックを基準として）
      final indexDiff = (i - widget.viewModel.selectedPackIndex) % packCount;
      final packAngle = 2 * pi * indexDiff / packCount;

      // 現在の回転角度を考慮した角度差（正面=0との差）
      double angleDiff = (packAngle + _rotationAngle).abs() % (2 * pi);
      if (angleDiff > pi) angleDiff = 2 * pi - angleDiff;

      // 最も小さい角度差を持つパックを選択
      if (angleDiff < minAngleDiff) {
        minAngleDiff = angleDiff;
        closestIndex = i;
      }
    }

    // 選択パックが変わったときだけ更新
    if (closestIndex != widget.viewModel.selectedPackIndex) {
      widget.onPackSelected(closestIndex);
      widget.playSelectSound();
    }
  }

  // 指定したパックインデックスに滑らかにアニメーション
  void _animateToPackIndex(int targetIndex) {
    if (targetIndex == widget.viewModel.selectedPackIndex) return;

    // 現在の回転角度
    final currentAngle = _rotationAngle;

    // 選択中のパックと目標パックの角度差
    final indexDiff =
        (targetIndex -
            widget.viewModel.selectedPackIndex +
            widget.viewModel.packs.length) %
        widget.viewModel.packs.length;
    final angleChange = -2 * pi * indexDiff / widget.viewModel.packs.length;

    // 最短経路の計算
    var targetAngle = currentAngle + angleChange;

    // アニメーションの持続時間（距離に応じて調整）
    final duration = Duration(
      milliseconds: min(800, (angleChange.abs() * 500).round()),
    );

    // 選択パックを先に更新
    widget.onPackSelected(targetIndex);
    widget.playSelectSound();

    // 回転アニメーション
    AnimationController animController = AnimationController(
      duration: duration,
      vsync: this,
    );

    Animation<double> anim = Tween<double>(
      begin: currentAngle,
      end: targetAngle,
    ).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
    );

    animController.addListener(() {
      setState(() {
        _rotationAngle = anim.value;
      });
    });

    animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animController.dispose();
      }
    });

    animController.forward();
  }

  // スワイプ終了時、選択中のパックが正面に来るように調整
  void _snapToSelectedPack() {
    if (widget.viewModel.isSelecting || widget.viewModel.packs.isEmpty) return;

    // 現在の回転角度を調整して、選択中のパックが正面に来るようにする
    final targetAngle =
        _rotationAngle.abs() < pi
            ? 0.0
            : _rotationAngle > 0
            ? 2 * pi
            : -2 * pi;

    // 小さな調整なら即座に適用、大きな調整ならアニメーション
    final angleDiff = (targetAngle - _rotationAngle).abs();
    if (angleDiff < 0.1) {
      setState(() {
        _rotationAngle = targetAngle;
      });
    } else {
      // アニメーションで滑らかに移動
      final duration = Duration(
        milliseconds: min(500, (angleDiff * 300).round()),
      );

      AnimationController animController = AnimationController(
        duration: duration,
        vsync: this,
      );

      Animation<double> anim = Tween<double>(
        begin: _rotationAngle,
        end: targetAngle,
      ).animate(
        CurvedAnimation(parent: animController, curve: Curves.easeOutCubic),
      );

      animController.addListener(() {
        setState(() {
          _rotationAngle = anim.value;
        });
      });

      animController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _rotationAngle = targetAngle % (2 * pi); // 確実に0〜2πの範囲に正規化
          });
          animController.dispose();
        }
      });

      animController.forward();
    }
  }
}
