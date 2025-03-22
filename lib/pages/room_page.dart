import 'package:flutter/material.dart';

class RoomPage extends StatelessWidget {
  final String roomId;
  final String player1Id;
  final String? player2Id;

  const RoomPage({
    super.key,
    required this.roomId,
    required this.player1Id,
    this.player2Id,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 戻るボタンを無効化
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Room Page'),
          automaticallyImplyLeading: false, // AppBarの戻るボタンを非表示
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Room ID: $roomId', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              Text(
                'Player 1 ID: $player1Id',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                'Player 2 ID: ${player2Id ?? "Waiting..."}',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
