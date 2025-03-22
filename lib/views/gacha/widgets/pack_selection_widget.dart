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

    final double radius = MediaQuery.of(context).size.width * 0.4; // 円の半径
    final double centerY =
        MediaQuery.of(context).size.height * 0.35; // 中心位置のY座標

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand, // スタックが利用可能な全領域を使用
            children: [
              // 背景のグラデーション - 透明にして実質削除
              Container(color: Colors.transparent),

              // 円形の軌道を示す半透明の円（横から見た楕円）- 透明度を高くして目立たなくする
              Positioned(
                left: MediaQuery.of(context).size.width * 0.05,
                right: MediaQuery.of(context).size.width * 0.05,
                top: centerY - MediaQuery.of(context).size.width * 0.15,
                child: Container(
                  height:
                      MediaQuery.of(context).size.width *
                      0.3, // 縦に潰して円が横から見える感じに
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.width * 0.15,
                    ),
                    border: Border.all(
                      color: Colors.deepPurple.withOpacity(
                        0.1,
                      ), // 透明度を高くして目立たなくする
                      width: 1, // 線を細くする
                    ),
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

              // パックを表示するとき、zIndex（前後関係）を明示的に制御する
              // 奥のパックから前方のパックへとZインデックスを考慮して描画
              ..._buildPackCards(context, packCount, radius, centerY),
            ],
          ),
        ),
      ],
    );
  }

  // パックカードを適切なZ順序で配置するヘルパーメソッド
  List<Widget> _buildPackCards(
    BuildContext context,
    int packCount,
    double radius,
    double centerY,
  ) {
    // 選択されたパックを基準に角度を計算
    final selectedIndex = widget.viewModel.selectedPackIndex;

    // 全パックのZ位置を計算し、奥から前へのソート用リスト
    final List<MapEntry<int, double>> packZOrder = [];

    for (int i = 0; i < packCount; i++) {
      // 各パックの角度を計算（選択中パックを基準として）
      final indexOffset = (i - selectedIndex) % packCount;
      final angle = (2 * pi * indexOffset / packCount) + _rotationAngle;

      // Z座標を計算（cos関数で前後位置を決定）
      final z = cos(angle) * radius;

      packZOrder.add(MapEntry(i, z));
    }

    // Zインデックスに基づいて奥から前へソート（Zが小さい＝奥のものから描画）
    packZOrder.sort((a, b) => a.value.compareTo(b.value));

    // ソートされた順序でパックウィジェットを作成
    final List<Widget> packWidgets = [];

    // 選択中のハイライト効果もここでは削除（黄色い背景の原因になるため）

    // 全てのパックカードを描画
    for (final entry in packZOrder) {
      final index = entry.key;
      final z = entry.value;

      // 選択インデックスとの差を計算（円周上の位置）
      final indexOffset = (index - selectedIndex) % packCount;
      // 角度を計算
      final angle = (2 * pi * indexOffset / packCount) + _rotationAngle;

      // X座標（sin関数で左右位置を決定）
      final x = sin(angle) * radius;

      // スケール（奥行きに応じて拡大/縮小）
      final scale = GachaUtils.map(z, -radius, radius, 0.6, 1.2);

      // Y座標の微調整（奥行き感を強調）
      final yOffset = -GachaUtils.map(z, -radius, radius, -10, 10);

      // 不透明度（奥のパックは少し透明に）
      final opacity = GachaUtils.map(z, -radius, radius, 0.5, 1.0);

      // 選択中かどうか
      final isSelected = index == selectedIndex;

      packWidgets.add(
        Positioned(
          left: MediaQuery.of(context).size.width / 2 + x - 75,
          top: centerY + yOffset,
          child: Transform(
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // パースペクティブ
                  ..scale(scale), // Z軸に応じたスケール
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity,
              child: GestureDetector(
                onTap:
                    widget.viewModel.isSelecting
                        ? null
                        : () => _animateToPackIndex(index),
                child: PackCard(
                  packData: widget.viewModel.packs[index],
                  isSelected: isSelected,
                  scale: 1.0,
                  rotation: 0.0,
                  onTap: null,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return packWidgets;
  }

  bool _isSelectedPackInFront() {
    // 選択中のパックは常に正面にあると考える
    return true;
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

      // パックが変わったら回転角度をリセット
      _rotationAngle = 0.0;
    }
  }

  // 指定したパックインデックスに滑らかにアニメーション
  void _animateToPackIndex(int targetIndex) {
    if (targetIndex == widget.viewModel.selectedPackIndex) return;

    // 選択パックを先に更新
    widget.onPackSelected(targetIndex);
    widget.playSelectSound();

    // 選択が変わったら回転角度をリセット
    setState(() {
      _rotationAngle = 0.0;
    });
  }

  // スワイプ終了時、選択中のパックが正面に来るように調整
  void _snapToSelectedPack() {
    if (widget.viewModel.isSelecting || widget.viewModel.packs.isEmpty) return;

    // 選択されたパックが正面にくるように回転角度をリセット
    setState(() {
      _rotationAngle = 0.0;
    });
  }
}
