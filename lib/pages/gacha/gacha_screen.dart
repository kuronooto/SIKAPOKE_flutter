import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/gacha_view_model.dart';
import 'widgets/gacha_screen_widget.dart';

/// ガチャメイン画面のエントリーポイント
///
/// カードガチャの機能を提供します。
/// 主要な処理は各Widgetに委譲し、このクラスは
/// 画面全体のコンテナとしての役割を果たします。
class GachaScreen extends StatelessWidget {
  final int? selectedPackTypeIndex; // 追加: 選択されたパックタイプのインデックス

  const GachaScreen({Key? key, this.selectedPackTypeIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ViewModelを取得
    GachaViewModel viewModel = Provider.of<GachaViewModel>(
      context,
      listen: false,
    );

    // もし外部からパックタイプインデックスが指定されていて、現在選択中のタイプと異なる場合は更新
    if (selectedPackTypeIndex != null &&
        selectedPackTypeIndex != viewModel.selectedPackTypeIndex) {
      // パックタイプを再設定
      // print('GachaScreen: パックタイプを${selectedPackTypeIndex}に設定します');
      viewModel.selectPackType(selectedPackTypeIndex!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('カードガチャ'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
      ),
      body: GachaScreenWidget(), // パックタイプが設定されたViewModelを使用
    );
  }
}
