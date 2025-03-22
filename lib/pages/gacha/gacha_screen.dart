import 'package:flutter/material.dart';
import 'widgets/gacha_screen_widget.dart';

/// ガチャメイン画面のエントリーポイント
///
/// 主要な処理は各Widgetに委譲しています。このクラスは
/// 画面全体のコンテナとしての役割を果たします。
class GachaScreen extends StatelessWidget {
  const GachaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: GachaScreenWidget());
  }
}
