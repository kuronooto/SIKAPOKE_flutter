import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../view_models/gacha_view_model.dart';
import '../../core/constants/asset_paths.dart';
import '../shared/app_theme.dart' as theme;
import 'widgets/pack_card.dart';
import 'widgets/result_dialog.dart';

class GachaScreen extends StatefulWidget {
  const GachaScreen({Key? key}) : super(key: key);

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen>
    with TickerProviderStateMixin {
  // アニメーションコントローラーの定義
  late AnimationController _selectionController;
  late AnimationController _openingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _openingAnimation;

  // 効果音プレーヤー
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundEnabled = true; // 音響効果の有効/無効フラグ

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

    // パック選択アニメーション
    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_selectionController);

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.05,
          end: -0.05,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.05,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 50,
      ),
    ]).animate(_selectionController);

    // パックオープンアニメーション
    _openingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _openingAnimation = CurvedAnimation(
      parent: _openingController,
      curve: Curves.easeInOutBack,
    );

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

    _selectionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Provider.of<GachaViewModel>(context, listen: false).completeSelection();
      }
    });

    _openingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 結果画面表示
        final viewModel = Provider.of<GachaViewModel>(context, listen: false);
        viewModel.completeOpening();

        if (viewModel.result != null) {
          // カード出現時の効果音を再生
          _playCardRevealSound(viewModel.result!.rarityLevel);

          Future.delayed(const Duration(milliseconds: 500), () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => ResultDialog(
                    result: viewModel.result!,
                    onClose: () {
                      Navigator.of(context).pop();
                      viewModel.resetSelection();
                    },
                  ),
            );
          });
        }
      }
    });

    // 開封アニメーション中の特定タイミングで効果音を再生
    _openingController.addListener(() {
      final value = _openingAnimation.value;
      // パックが開き始めるタイミングで効果音を再生
      if (value >= 0.3 && value <= 0.32) {
        _playPackOpenSound();
      }
      // カードが現れ始めるタイミングで効果音を再生
      else if (value >= 0.6 && value <= 0.62) {
        final viewModel = Provider.of<GachaViewModel>(context, listen: false);
        if (viewModel.result != null) {
          // 高レア度の場合はより派手な効果音
          if (viewModel.result!.rarityLevel >= 3) {
            _playSound('sounds/sparkle.mp3');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _openingController.dispose();
    _rotationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // 効果音を再生するヘルパーメソッド
  Future<void> _playSound(String soundPath) async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      debugPrint('効果音の再生に失敗しました: $e');
    }
  }

  // 選択時の効果音
  void _playSelectSound() {
    _playSound('sounds/select.mp3');
  }

  // パック開封時の効果音
  void _playPackOpenSound() {
    _playSound('sounds/open.mp3');
  }

  // カード出現時の効果音（レア度に応じて異なる効果音）
  void _playCardRevealSound(int rarityLevel) {
    if (rarityLevel >= 4) {
      _playSound('sounds/result_legendary.mp3');
    } else if (rarityLevel >= 3) {
      _playSound('sounds/result_rare.mp3');
    } else {
      _playSound('sounds/result.mp3');
    }
  }

  void _startPackSelection() {
    final viewModel = Provider.of<GachaViewModel>(context, listen: false);
    viewModel.startPackSelection();
    _selectionController.reset();
    _selectionController.forward();
    _playSelectSound(); // 選択効果音
  }

  void _openSelectedPack() {
    final viewModel = Provider.of<GachaViewModel>(context, listen: false);
    viewModel.openSelectedPack();
    _openingController.reset();
    _openingController.forward();
    _playPackOpenSound(); // 開封効果音
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // サウンド切り替えボタン
                    IconButton(
                      icon: Icon(
                        _soundEnabled ? Icons.volume_up : Icons.volume_off,
                        color: Colors.deepPurple,
                      ),
                      onPressed: () {
                        setState(() {
                          _soundEnabled = !_soundEnabled;
                        });
                      },
                    ),
                    const Text(
                      'ぽけぽけガチャ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    // バランス用の透明なダミーボタン
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Consumer<GachaViewModel>(
                  builder: (context, viewModel, child) {
                    return viewModel.isOpening
                        ? _buildPackOpeningAnimation(viewModel)
                        : _buildPackSelectionGrid(viewModel);
                  },
                ),
              ),
              const SizedBox(height: 20),
              Consumer<GachaViewModel>(
                builder: (context, viewModel, child) {
                  if (viewModel.isOpening) return const SizedBox.shrink();

                  return Transform(
                    transform:
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // パースペクティブ効果
                          ..rotateX(0.1), // X軸方向に少し傾ける（3D効果）
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                          BoxShadow(
                            color: Colors.deepPurple.shade300.withOpacity(0.3),
                            offset: const Offset(0, -2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed:
                            viewModel.hasSelectedPack
                                ? _openSelectedPack
                                : _startPackSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 10, // 高いelevationで浮き上がり感
                        ),
                        child: Text(
                          viewModel.hasSelectedPack ? 'パックを開ける' : 'パックを選ぶ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackSelectionGrid(GachaViewModel viewModel) {
    // パックを3D空間の円周上に配置し、選択中のパックが円の手前（Z軸最大）の位置に来るようにする

    final int packCount = viewModel.packs.length;
    if (packCount == 0) return const SizedBox.shrink(); // パックがない場合は何も表示しない

    // 選択インデックスが無効な場合は0に設定
    if (viewModel.selectedPackIndex < 0 ||
        viewModel.selectedPackIndex >= packCount) {
      // 範囲外の場合は最初のパックを選択
      viewModel.selectPack(0);
    }

    final double radius = MediaQuery.of(context).size.width * 0.33;

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

              // 円形の軌道を示す半透明の円
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.deepPurple.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),

              // 360度回転を検出する透明なコントロール
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
                  if (viewModel.isSelecting) return;

                  final currentX = details.globalPosition.dx;
                  final currentY = details.globalPosition.dy;

                  final dx = currentX - _lastPanX;

                  final rotationDelta = dx / 100 * -0.1; // 左右の回転方向を調整

                  setState(() {
                    _rotationAngle += rotationDelta;
                    _rotationVelocity = rotationDelta * 2;
                    _lastPanX = currentX;
                    _lastPanY = currentY;

                    _updateSelectedPackFromRotation(viewModel);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    _isDragging = false;

                    final velocity = details.velocity.pixelsPerSecond;
                    final speed = velocity.distance;
                    if (speed > 100) {
                      final direction = velocity.dx > 0 ? -1.0 : 1.0; // 回転方向を反転
                      _rotationVelocity = direction * min(speed / 1000, 0.1);
                    }
                  });

                  // パンが終了したら、選択中のパックが正面に来るようにアニメーション
                  _snapToSelectedPack(viewModel);
                },
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                ),
              ),

              // 全てのパックを円周上に配置
              ...List.generate(packCount, (index) {
                // 選択中のパックを0度（正面、Z軸最大）とし、他のパックの角度を計算
                final indexDiff =
                    (index - viewModel.selectedPackIndex) % packCount;
                final angle = (2 * pi * indexDiff / packCount) + _rotationAngle;

                // 3D位置の計算
                final x = cos(angle) * radius;
                final z = sin(angle) * radius;
                final y = -z * 0.2; // Z値に応じたY軸の調整（3D効果）

                // 選択中かどうか
                final isSelected = index == viewModel.selectedPackIndex;

                // Z値に基づくスケールと不透明度の計算
                final scale = map(z, -radius, radius, 0.7, 1.0);
                final opacity = map(z, -radius, radius, 0.6, 1.0);

                // パックが正面（Z軸最大）にあるかどうか
                final isInFront = z > radius * 0.7; // 正面判定の閾値

                return Positioned(
                  left: MediaQuery.of(context).size.width / 2 + x - 70,
                  top: MediaQuery.of(context).size.height / 3 + y - 98,
                  child: Transform(
                    transform:
                        Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // パースペクティブ
                          ..scale(scale), // Z軸に応じたスケール
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: opacity,
                      child: Stack(
                        children: [
                          // パックカード
                          GestureDetector(
                            onTap:
                                viewModel.isSelecting
                                    ? null
                                    : () {
                                      _animateToPackIndex(viewModel, index);
                                    },
                            child: PackCard(
                              packData: viewModel.packs[index],
                              isSelected: isSelected && isInFront,
                              scale: 1.0,
                              rotation: 0.0,
                              onTap: null,
                            ),
                          ),

                          // 選択中かつ正面にあるパックに「選択中」バッジを表示
                          if (isSelected && isInFront)
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
                top: MediaQuery.of(context).size.height / 3 - 110,
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
              if (_isSelectedPackInFront(viewModel))
                Positioned(
                  left: MediaQuery.of(context).size.width / 2 - 80,
                  top: MediaQuery.of(context).size.height / 3 - 110,
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

  bool _isSelectedPackInFront(GachaViewModel viewModel) {
    if (viewModel.selectedPackIndex < 0 || viewModel.packs.isEmpty)
      return false;

    // 選択中のパックの角度
    final angle = _rotationAngle;

    // 正面判定（Z軸が正の値で、かつある程度大きい場合）
    return angle.abs() < 0.3; // 正面の許容範囲
  }

  // 回転角度から選択中のパックインデックスを更新
  void _updateSelectedPackFromRotation(GachaViewModel viewModel) {
    final packCount = viewModel.packs.length;
    if (packCount == 0) return;

    // 回転角度に基づいて、どのパックが最も正面に近いかを計算
    double minAngleDiff = double.infinity;
    int closestIndex = viewModel.selectedPackIndex;

    for (int i = 0; i < packCount; i++) {
      // 各パックの角度を計算（選択中パックを基準として）
      final offset = (i - viewModel.selectedPackIndex) % packCount;
      final packAngle = 2 * pi * offset / packCount;

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
    if (closestIndex != viewModel.selectedPackIndex) {
      viewModel.selectPack(closestIndex);
      _playSelectSound();
    }
  }

  // 指定したパックインデックスに滑らかにアニメーション
  void _animateToPackIndex(GachaViewModel viewModel, int targetIndex) {
    if (targetIndex == viewModel.selectedPackIndex) return;

    // 現在の回転角度
    final currentAngle = _rotationAngle;

    // 選択中のパックと目標パックの角度差
    final indexDiff =
        (targetIndex - viewModel.selectedPackIndex + viewModel.packs.length) %
        viewModel.packs.length;
    final angleChange = -2 * pi * indexDiff / viewModel.packs.length;

    // 最短経路の計算
    var targetAngle = currentAngle + angleChange;

    // アニメーションの持続時間（距離に応じて調整）
    final duration = Duration(
      milliseconds: min(800, (angleChange.abs() * 500).round()),
    );

    // 選択パックを先に更新
    viewModel.selectPack(targetIndex);
    _playSelectSound();

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
  void _snapToSelectedPack(GachaViewModel viewModel) {
    if (viewModel.isSelecting || viewModel.packs.isEmpty) return;

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

  // 値の範囲をマッピングするユーティリティ関数
  double map(
    double value,
    double fromLow,
    double fromHigh,
    double toLow,
    double toHigh,
  ) {
    return toLow + (value - fromLow) * (toHigh - toLow) / (fromHigh - fromLow);
  }

  Widget _buildPackOpeningAnimation(GachaViewModel viewModel) {
    final selectedPack = viewModel.packs[viewModel.selectedPackIndex];
    final rarityLevel = selectedPack.rarityLevel;

    // レア度の星の色を取得
    Color _getRarityStarColor(int rarityLevel) {
      switch (rarityLevel) {
        case 1:
          return Colors.white;
        case 2:
          return Colors.yellow.shade200;
        case 3:
          return Colors.yellow;
        case 4:
          return Colors.amber;
        case 5:
          return Colors.orange;
        default:
          return Colors.white;
      }
    }

    final List<Color> bgColors = _getBackgroundColors(rarityLevel);
    final Color glowColor = _getGlowColor(rarityLevel);

    return AnimatedBuilder(
      animation: _openingAnimation,
      builder: (context, child) {
        final value = _openingAnimation.value;

        // スワイプでパックを開封するインタラクティブな演出
        if (value < 0.3) {
          // パックにスワイプを促すUI
          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! > 300) {
                  // 右から左への速いスワイプでアニメーションを加速
                  _openingController.animateTo(
                    0.3,
                    duration: const Duration(milliseconds: 200),
                  );
                  _playPackOpenSound();
                } else if (details.primaryVelocity! < -300) {
                  // 左から右への速いスワイプでもアニメーションを加速
                  _openingController.animateTo(
                    0.3,
                    duration: const Duration(milliseconds: 200),
                  );
                  _playPackOpenSound();
                }
              }
            },
            onTap: () {
              // タップでもアニメーションを進める（ユーザーの好みに合わせて）
              _openingController.animateTo(
                0.3,
                duration: const Duration(milliseconds: 200),
              );
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
                                              DateTime.now()
                                                      .millisecondsSinceEpoch /
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
        // パックが開いて中身が見える演出
        else if (value < 0.6) {
          // パックが開いていく演出
          final openingProgress = (value - 0.3) / 0.3; // 0.3~0.6を0~1にマッピング

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
                    width: 250 + openingProgress * 100,
                    height: 330 + openingProgress * 100,
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
                          ..rotateY(pi * openingProgress),
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
                            1.0 - openingProgress,
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
        // カードが現れる最終演出
        else {
          final cardRevealProgress = (value - 0.6) / 0.4; // 0.6~1.0を0~1にマッピング

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
                    width: 300 + cardRevealProgress * 200,
                    height: 400 + cardRevealProgress * 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glowColor.withOpacity(
                            0.7 * (1.0 - cardRevealProgress),
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
                      final distance = 150 + cardRevealProgress * 100;
                      return Positioned(
                        left: 150 + cos(angle) * distance * cardRevealProgress,
                        top: 150 + sin(angle) * distance * cardRevealProgress,
                        child: Opacity(
                          opacity: 1.0 - cardRevealProgress * 0.8,
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
                          ..rotateY(pi * (1.0 - cardRevealProgress)),
                    child: Container(
                      width: 220,
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _getCardGradient(rarityLevel),
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
                              _getRarityText(rarityLevel),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              _getRarityStars(rarityLevel),
                              style: TextStyle(
                                color: _getRarityStarColor(rarityLevel),
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
      },
    );
  }

  // レア度に応じた背景色を取得
  List<Color> _getBackgroundColors(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return [Colors.deepPurple.shade100, Colors.deepPurple.shade200];
      case 2:
        return [Colors.deepPurple.shade200, Colors.deepPurple.shade300];
      case 3:
        return [Colors.deepPurple.shade300, Colors.deepPurple.shade400];
      case 4:
        return [Colors.deepPurple.shade400, Colors.deepPurple.shade500];
      default:
        return [Colors.deepPurple.shade100, Colors.deepPurple.shade200];
    }
  }

  // レア度に応じた光るエフェクトの色を取得
  Color _getGlowColor(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Colors.blue.shade400;
      case 2:
        return Colors.purple.shade400;
      case 3:
        return Colors.pink.shade300;
      case 4:
        return Colors.yellow.shade300;
      default:
        return Colors.blue.shade400;
    }
  }

  // レア度に応じたカードのグラデーションを取得
  List<Color> _getCardGradient(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return [Colors.deepPurple.shade300, Colors.deepPurple.shade200];
      case 2:
        return [Colors.deepPurple.shade400, Colors.deepPurple.shade300];
      case 3:
        return [Colors.deepPurple.shade500, Colors.deepPurple.shade400];
      case 4:
        return [Colors.deepPurple.shade700, Colors.deepPurple.shade500];
      case 5:
        return [Colors.deepPurple.shade900, Colors.purple.shade300];
      default:
        return [Colors.deepPurple.shade300, Colors.deepPurple.shade200];
    }
  }

  // レア度に応じたテキストを取得
  String _getRarityText(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return 'ノーマル';
      case 2:
        return 'レア';
      case 3:
        return 'スーパーレア';
      case 4:
        return 'ウルトラレア';
      case 5:
        return 'レジェンド';
      default:
        return 'ノーマル';
    }
  }

  // レア度の星表示を取得
  String _getRarityStars(int rarityLevel) {
    return '★' * rarityLevel;
  }

  // レ // レア度の星の色を取得
  Color _getRarityStarColor(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Colors.white;
      case 2:
        return Colors.yellow.shade200;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.amber;
      case 5:
        return Colors.orange;
      default:
        return Colors.white;
    }
  }
}
