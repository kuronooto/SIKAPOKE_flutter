import 'package:flutter/material.dart';

class BattlePage extends StatefulWidget {
  const BattlePage({super.key});

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Battle Page'));
  }
}
