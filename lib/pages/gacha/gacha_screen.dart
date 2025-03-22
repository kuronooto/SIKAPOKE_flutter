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
  const GachaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カードガチャ'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
      ),
      body: ChangeNotifierProvider(
        create: (context) => GachaViewModel(),
        child: const GachaScreenWidget(),
      ),
    );
  }
}
