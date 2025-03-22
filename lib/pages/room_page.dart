import 'package:flutter/material.dart';

class RoomPage extends StatelessWidget {
  final String roomId;
  final String player1Id;
  final String? player2Id;
  final Map<String, dynamic> gameState; // game_state を受け取る

  const RoomPage({
    super.key,
    required this.roomId,
    required this.player1Id,
    this.player2Id,
    required this.gameState,
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
              const SizedBox(height: 20),
              const Text(
                'Game State:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Turn: ${gameState['turn']}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'Player 1 Points: ${gameState['player1_point']}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'Player 2 Points: ${gameState['player2_point']}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'Player 1 Over Mount: ${gameState['player1_over_mount']}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'Player 2 Over Mount: ${gameState['player2_over_mount']}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
