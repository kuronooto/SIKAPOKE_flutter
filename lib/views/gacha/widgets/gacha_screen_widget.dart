import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../view_models/gacha_view_model.dart';
import '../../shared/app_theme.dart' as theme;
import 'pack_selection_widget.dart';
import 'pack_opening_animation.dart';
import 'result_dialog.dart';
import 'sound_service.dart';

class GachaScreenWidget extends StatefulWidget {
  const GachaScreenWidget({Key? key}) : super(key: key);

  @override
  State<GachaScreenWidget> createState() => _GachaScreenWidgetState();
}

class _GachaScreenWidgetState extends State<GachaScreenWidget>
    with TickerProviderStateMixin {
  // アニメーションコントローラーの定義
  late AnimationController _selectionController;
  late AnimationController _openingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _openingAnimation;

  // 効果音サービス
  final SoundService _soundService = SoundService();

  // パック開封フラグ
  bool _waitingForSwipe = false;

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
          _soundService.playCardRevealSound(viewModel.result!.rarityLevel);

          Future.delayed(const Duration(milliseconds: 500), () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => ResultDialog(
                    result: viewModel.result!,
                    onClose: () {
                      Navigator.of(context).pop();

                      // 全ステートを完全にリセット
                      _resetAllStates();
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
        _soundService.playPackOpenSound();
      }
      // カードが現れ始めるタイミングで効果音を再生
      else if (value >= 0.6 && value <= 0.62) {
        final viewModel = Provider.of<GachaViewModel>(context, listen: false);
        if (viewModel.result != null) {
          // 高レア度の場合はより派手な効果音
          if (viewModel.result!.rarityLevel >= 3) {
            _soundService.playSparkleSound();
          }
        }
      }
    });
  }

  // 全ての状態を完全にリセット
  void _resetAllStates() {
    final viewModel = Provider.of<GachaViewModel>(context, listen: false);

    // ViewModel内の状態をリセット
    viewModel.resetSelection();

    // アニメーションコントローラをリセット
    _selectionController.reset();
    _openingController.reset();

    // 開封待ちフラグをリセット
    setState(() {
      _waitingForSwipe = false;
    });

    // イベントリスナーがアクティブな場合はキャンセル
    if (_openingController.isAnimating) {
      _openingController.stop();
    }
    if (_selectionController.isAnimating) {
      _selectionController.stop();
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _openingController.dispose();
    _soundService.dispose();
    super.dispose();
  }

  void _startPackSelection() {
    final viewModel = Provider.of<GachaViewModel>(context, listen: false);
    viewModel.startPackSelection();
    _selectionController.reset();
    _selectionController.forward();
    _soundService.playSelectSound(); // 選択効果音
  }

  void _openSelectedPack() {
    // 前回のアニメーション状態をクリア
    _openingController.reset();

    // パック開封前の状態フラグを設定
    setState(() {
      _waitingForSwipe = true;
    });

    final viewModel = Provider.of<GachaViewModel>(context, listen: false);
    viewModel.openSelectedPack();

    // 注：実際の開封アニメーションはスワイプやタップ時にのみ開始される
    // _openingController はスワイプやタップ時に進行する
  }

  void _onPackSelected(int index) {
    Provider.of<GachaViewModel>(context, listen: false).selectPack(index);
  }

  void _onPackSwiped() {
    // スワイプされた場合にのみアニメーションを開始
    if (_waitingForSwipe) {
      // スライス効果の触覚フィードバック（振動）を追加
      HapticFeedback.mediumImpact();

      // アニメーションコントローラーをリセット
      _openingController.reset();

      // スライス効果用の特殊なカーブを使用
      final customCurve = CurvedAnimation(
        parent: _openingController,
        // 最初に急速に加速し、その後徐々に減速するカスタムカーブ
        curve: Curves.easeOutBack,
      );

      // アニメーションを開始
      _openingController.forward(from: 0.0);

      // 効果音を再生
      _soundService.playPackOpenSound(); // 基本の開封効果音
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // グラデーションを使用するが、薄い色にする
      decoration: BoxDecoration(
        color: Colors.white, // 白ベースの背景
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50, // 非常に薄い青
            Colors.purple.shade50, // 非常に薄い紫
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<GachaViewModel>(
                builder: (context, viewModel, child) {
                  return viewModel.isOpening
                      ? PackOpeningAnimation(
                        viewModel: viewModel,
                        animation: _openingAnimation,
                        onPackSwiped: _onPackSwiped,
                        playPackOpenSound: _soundService.playPackOpenSound,
                      )
                      : PackSelectionWidget(
                        viewModel: viewModel,
                        onPackSelected: _onPackSelected,
                        playSelectSound: _soundService.playSelectSound,
                      );
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildBottomButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // サウンド切り替えボタン
          IconButton(
            icon: Icon(
              _soundService.isSoundEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.deepPurple,
            ),
            onPressed: () {
              setState(() {
                _soundService.toggleSound();
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
    );
  }

  Widget _buildBottomButton() {
    return Consumer<GachaViewModel>(
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
    );
  }
}
