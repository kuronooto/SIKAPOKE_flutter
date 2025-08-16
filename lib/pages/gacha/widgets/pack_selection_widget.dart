import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../../../viewmodels/gacha_view_model.dart';
import '../../../models/pack_model.dart'; // PackModelをインポート
import 'gacha_utils.dart';
import 'pack_card.dart';
import 'pack_card.dart' show SwipeDirection; // SwipeDirection列挙型のインポート

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
  bool _isAnimating = false; // アニメーション中フラグ
  double _dragThreshold = 2.0; // 非常に小さな動きでも検出

  // 選択アニメーション用の変数
  int _targetPackIndex = -1; // アニメーション対象のパックインデックス
  int _oldSelectedIndex = -1; // 以前選択されていたパックインデックス
  double _animationProgress = 0.0; // アニメーションの進行状況（0.0-1.0）
  bool _clockwiseRotation = true; // 回転方向（時計回りか反時計回りか）
  double _startAngle = 0.0; // アニメーション開始時の角度
  double _targetAngle = 0.0; // アニメーション終了時の角度
  double _angleDelta = 0.0; // アニメーションで回転する角度

  // アニメーション用コントローラ
  late AnimationController _rotationController;
  late AnimationController _selectionAnimController;

  // 追加: Functions
  late final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  void initState() {
    super.initState();

    // 3D回転アニメーション用コントローラ
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10), // 長めの持続時間
      vsync: this,
    )..addListener(() {
      if (_rotationVelocity != 0 && !_isDragging && !_isAnimating) {
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

    // パック選択アニメーション用コントローラ
    _selectionAnimController = AnimationController(
      duration: const Duration(milliseconds: 400), // アニメーション時間を短縮
      vsync: this,
    );

    // アニメーションの進行状況を監視
    _selectionAnimController.addListener(() {
      setState(() {
        _animationProgress = _selectionAnimController.value;
      });
    });

    // アニメーション完了時の処理
    _selectionAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isAnimating = false;
          _rotationAngle = 0.0; // 確実に0に設定
          _oldSelectedIndex = widget.viewModel.selectedPackIndex;
          _targetPackIndex = -1;
        });
      }
    });

    _rotationController.repeat(); // 常に更新
    _oldSelectedIndex = widget.viewModel.selectedPackIndex;

    // エミュレータ
    if (kDebugMode) {
      try {
        _functions.useFunctionsEmulator('localhost', 5001);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _selectionAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // パックを3D空間の円周上に配置し、横方向に回転するように表示

    final List<dynamic> packs = widget.viewModel.packs;
    final int packCount = packs.length;

    if (packCount == 0) {
      // デバッグ表示
      // print('PackSelectionWidget: パックが空です');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'パックが見つかりません',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.viewModel.selectPack(0); // デフォルトパック（最強の資格）を生成
              },
              child: Text('パックを初期化'),
            ),
          ],
        ),
      );
    }

    // 選択インデックスが無効な場合は0に設定
    if (widget.viewModel.selectedPackIndex < 0 ||
        widget.viewModel.selectedPackIndex >= packCount) {
      // 範囲外の場合は最初のパックを選択
      widget.viewModel.selectPack(0);
      _oldSelectedIndex = 0;
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
                  if (_isAnimating) return; // アニメーション中はドラッグを無視

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
                  if (widget.viewModel.isSelecting || _isAnimating) return;

                  final currentX = details.globalPosition.dx;
                  final currentY = details.globalPosition.dy;

                  final dx = currentX - _lastPanX;

                  if (dx.abs() > _dragThreshold) {
                    // 感度を大幅増加
                    final rotationDelta = dx / 100 * -0.45;

                    setState(() {
                      _rotationAngle += rotationDelta;
                      // 回転速度も大幅に増加
                      _rotationVelocity = rotationDelta * 3.5;
                      _lastPanX = currentX;
                      _lastPanY = currentY;

                      _updateSelectedPackFromRotation();
                    });
                  }
                },
                onPanEnd: (details) {
                  if (_isAnimating) return;

                  setState(() {
                    _isDragging = false;

                    final velocity = details.velocity.pixelsPerSecond;
                    final speed = velocity.distance;
                    // より小さな動きでもフリックとして検出 (閾値を30に下げる)
                    if (speed > 30) {
                      final direction = velocity.dx > 0 ? -1.0 : 1.0;
                      // より強い回転を適用
                      _rotationVelocity = direction * min(speed / 500, 0.4);
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
    // パックが存在しない場合は空のリストを返す
    if (packCount == 0) {
      // デバッグログを追加
      // print('PackSelectionWidget: パックが空です');
      return [];
    }

    // デバッグログ - パックの情報を表示
    // print('PackSelectionWidget: ${packCount}枚のパックを表示します');
    for (int i = 0; i < min(3, packCount); i++) {
      // print(
      //   'Pack[$i]: ${widget.viewModel.packs[i].name}, 色: ${widget.viewModel.packs[i].color}',
      // );
    }

    // 選択されたパックを基準に角度を計算
    final selectedIndex = widget.viewModel.selectedPackIndex;

    // 全パックのZ位置を計算し、奥から前へのソート用リスト
    final List<MapEntry<int, double>> packZOrder = [];

    for (int i = 0; i < packCount; i++) {
      // 各パックの角度を計算
      double angle;

      if (_isAnimating && _targetPackIndex != -1) {
        // アニメーション中：アニメーションの進行状況に応じて角度を計算
        angle = _calculateAnimationAngle(i, packCount);
      } else {
        // 通常時：選択中パックを基準に角度を計算
        final indexOffset = (i - selectedIndex) % packCount;
        angle = (2 * pi * indexOffset / packCount) + _rotationAngle;
      }

      // Z座標を計算（cos関数で前後位置を決定）
      final z = cos(angle) * radius;

      packZOrder.add(MapEntry(i, z));
    }

    // Zインデックスに基づいて奥から前へソート（Zが小さい＝奥のものから描画）
    packZOrder.sort((a, b) => a.value.compareTo(b.value));

    // ソートされた順序でパックウィジェットを作成
    final List<Widget> packWidgets = [];

    // 全てのパックカードを描画
    for (final entry in packZOrder) {
      final index = entry.key;
      final z = entry.value;

      // 選択されたパックタイプからパックモデルを取得
      final PackModel packData = widget.viewModel.packs[index];

      // 角度を決定
      double angle;

      if (_isAnimating && _targetPackIndex != -1) {
        // アニメーション中
        angle = _calculateAnimationAngle(index, packCount);
      } else {
        // 通常時
        final indexOffset = (index - selectedIndex) % packCount;
        angle = (2 * pi * indexOffset / packCount) + _rotationAngle;
      }

      // X座標（sin関数で左右位置を決定）
      final x = sin(angle) * radius;

      // スケール（奥行きに応じて拡大/縮小）
      final scale = GachaUtils.map(z, -radius, radius, 0.6, 1.2);

      // Y座標の微調整（奥行き感を強調）
      final yOffset = -GachaUtils.map(z, -radius, radius, -10, 10);

      // 不透明度（奥のパックは少し透明に）
      final opacity = GachaUtils.map(z, -radius, radius, 0.5, 1.0);

      // 選択中かどうか
      final isSelected =
          _isAnimating ? (index == _targetPackIndex) : (index == selectedIndex);

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
                    widget.viewModel.isSelecting || _isAnimating
                        ? null
                        : () => _animateToPackIndex(index),
                child: PackCard(
                  packData: packData,
                  isSelected: isSelected,
                  scale: 1.0,
                  rotation: 0.0,
                  onTap: null,
                  // 新規追加: スワイプコールバック
                  onSwipe:
                      widget.viewModel.isSelecting || _isAnimating
                          ? null
                          : (direction) {
                            // スワイプ方向に基づいて次/前のパックを選択
                            final packCount = widget.viewModel.packs.length;
                            int targetIndex;

                            // スワイプ方向によって異なる処理
                            if (direction == SwipeDirection.left) {
                              // 左スワイプ - 次のパックへ（現在のインデックスから+1）
                              targetIndex = (selectedIndex + 1) % packCount;
                            } else {
                              // 右スワイプ - 前のパックへ（現在のインデックスから-1）
                              targetIndex =
                                  (selectedIndex - 1 + packCount) % packCount;
                            }

                            // 選択したパックにアニメーションで移動
                            _animateToPackIndex(targetIndex);
                          },
                ),
              ),
            ),
          ),
        ),
      );
    }

    return packWidgets;
  }

  // アニメーション中の角度を計算するヘルパーメソッド
  double _calculateAnimationAngle(int index, int packCount) {
    if (index == _targetPackIndex) {
      // ターゲットパック：徐々に前面（0度）に移動
      return _startAngle * (1.0 - _animationProgress);
    } else {
      // 各パックの現在の位置を計算
      double currentAngle;

      // 開始位置と終了位置の角度を計算
      double startAngle;
      double targetAngle;

      // 開始時のパック位置を計算
      int oldOffsetInt = (index - _oldSelectedIndex) % packCount;
      double oldOffset = oldOffsetInt.toDouble();

      if (oldOffset > packCount / 2) {
        oldOffset -= packCount;
      } else if (oldOffset < -packCount / 2) {
        oldOffset += packCount;
      }
      startAngle = (2 * pi * oldOffset / packCount) + _rotationAngle;

      // 目標位置のパック位置を計算
      int newOffsetInt = (index - _targetPackIndex) % packCount;
      double newOffset = newOffsetInt.toDouble();

      if (newOffset > packCount / 2) {
        newOffset -= packCount;
      } else if (newOffset < -packCount / 2) {
        newOffset += packCount;
      }
      targetAngle = (2 * pi * newOffset / packCount);

      // 最短経路をとる角度補間
      double diff = targetAngle - startAngle;

      // 角度の差が±πを超える場合、反対方向に回る
      if (diff > pi) {
        diff -= 2 * pi;
      } else if (diff < -pi) {
        diff += 2 * pi;
      }

      currentAngle = startAngle + diff * _animationProgress;
      return currentAngle;
    }
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
      // 各パックの角度を計算（現在の回転角度を考慮）
      final int indexDiffInt =
          (i - widget.viewModel.selectedPackIndex) % packCount;

      // 明示的に double に変換
      double normalizedDiff = indexDiffInt.toDouble();
      if (normalizedDiff > packCount / 2) {
        normalizedDiff -= packCount;
      } else if (normalizedDiff < -packCount / 2) {
        normalizedDiff += packCount;
      }

      final packAngle = 2 * pi * normalizedDiff / packCount;

      // 現在の回転角度を考慮した角度差
      double angleDiff = (packAngle + _rotationAngle).abs();
      if (angleDiff > pi) angleDiff = 2 * pi - angleDiff;

      if (angleDiff < minAngleDiff) {
        minAngleDiff = angleDiff;
        closestIndex = i;
      }
    }

    // 非常に小さな閾値で更新を行う
    // または、異なるパックが検出された場合は必ず更新
    if (closestIndex != widget.viewModel.selectedPackIndex ||
        (_rotationAngle.abs() > 0.05 && minAngleDiff < 0.3)) {
      _prepareAnimation(
        widget.viewModel.selectedPackIndex,
        closestIndex,
        packCount,
      );

      widget.onPackSelected(closestIndex);
      widget.playSelectSound();

      _startSelectionAnimation();
    }
  }

  // 指定したパックインデックスに滑らかにアニメーション
  void _animateToPackIndex(int targetIndex) {
    if (targetIndex == widget.viewModel.selectedPackIndex || _isAnimating)
      return;

    final packCount = widget.viewModel.packs.length;
    _prepareAnimation(
      widget.viewModel.selectedPackIndex,
      targetIndex,
      packCount,
    );

    // 選択パックを更新
    widget.onPackSelected(targetIndex);
    widget.playSelectSound();

    // アニメーションを開始
    _startSelectionAnimation();
  }

  // アニメーションの準備：最短経路の計算など
  void _prepareAnimation(int oldIndex, int newIndex, int packCount) {
    _oldSelectedIndex = oldIndex;
    _targetPackIndex = newIndex;

    // 現在のターゲットパックの角度を取得
    int oldOffsetInt = (newIndex - oldIndex) % packCount;

    // 明示的に double に変換
    double oldOffset = oldOffsetInt.toDouble();

    // 最短経路を計算
    if (oldOffset > packCount / 2) {
      oldOffset -= packCount;
      _clockwiseRotation = false;
    } else if (oldOffset < -packCount / 2) {
      oldOffset += packCount;
      _clockwiseRotation = true;
    } else {
      // 通常の経路
      _clockwiseRotation = oldOffset > 0;
    }

    // ターゲットパックの現在の角度
    _startAngle = (2 * pi * oldOffset / packCount) + _rotationAngle;
    // 目標角度は0（正面）
    _targetAngle = 0.0;
    // 回転する角度
    _angleDelta = _targetAngle - _startAngle;
  }

  // 選択アニメーションを開始
  void _startSelectionAnimation() {
    setState(() {
      _isAnimating = true;
      _animationProgress = 0.0;
    });

    _selectionAnimController.reset();
    _selectionAnimController.forward();
  }

  // スワイプ終了時、選択中のパックが正面に来るようにアニメーションで調整
  void _snapToSelectedPack() {
    if (widget.viewModel.isSelecting ||
        widget.viewModel.packs.isEmpty ||
        _isAnimating)
      return;

    // より小さな角度でもスナップするよう閾値を下げる
    if (_rotationAngle.abs() < 0.02) return;

    final packCount = widget.viewModel.packs.length;
    _prepareAnimation(
      widget.viewModel.selectedPackIndex,
      widget.viewModel.selectedPackIndex,
      packCount,
    );
    _startSelectionAnimation();
  }
}
