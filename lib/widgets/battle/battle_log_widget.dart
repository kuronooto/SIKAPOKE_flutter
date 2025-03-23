import 'package:flutter/material.dart';

class BattleLogWidget extends StatelessWidget {
  final Map<String, dynamic> logs;
  final int turn;

  const BattleLogWidget({Key? key, required this.logs, required this.turn})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player1Log = logs['player1_log'] as Map<String, dynamic>? ?? {};
    final player2Log = logs['player2_log'] as Map<String, dynamic>? ?? {};

    // elementとpowerの配列を取得
    final player1Elements = List<String>.from(player1Log['element'] ?? []);
    final player1Powers = List<int>.from(player1Log['power'] ?? []);
    final player2Elements = List<String>.from(player2Log['element'] ?? []);
    final player2Powers = List<int>.from(player2Log['power'] ?? []);

    // 表示するログの最大数
    final maxLogs = 5;
    final logCount = player1Powers.length;
    // 最新のログのみ表示
    final startIndex = logCount > maxLogs ? logCount - maxLogs : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'バトルログ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          if (logCount == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('バトル履歴はまだありません'),
              ),
            )
          else
            for (int i = startIndex; i < logCount; i++)
              _buildLogEntry(
                i + 1,
                player1Elements.length > i ? player1Elements[i] : '',
                player1Powers.length > i ? player1Powers[i] : 0,
                player2Elements.length > i ? player2Elements[i] : '',
                player2Powers.length > i ? player2Powers[i] : 0,
                context,
              ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(
    int turnNumber,
    String player1Element,
    int player1Power,
    String player2Element,
    int player2Power,
    BuildContext context,
  ) {
    // タイプ相性による倍率を計算
    final Map<String, String> typeWeakness = {
      "IT": "語学",
      "語学": "ビジネス",
      "ビジネス": "IT",
    };

    int player1FinalPower = player1Power;
    int player2FinalPower = player2Power;

    if (typeWeakness[player1Element] == player2Element) {
      player1FinalPower *= 2;
    }
    if (typeWeakness[player2Element] == player1Element) {
      player2FinalPower *= 2;
    }

    // 勝敗判定
    String result = '引き分け';
    Color resultColor = Colors.grey;
    if (player1FinalPower > player2FinalPower) {
      result = 'Player 1 勝利';
      resultColor = Colors.blue;
    } else if (player1FinalPower < player2FinalPower) {
      result = 'Player 2 勝利';
      resultColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // ターン番号
          SizedBox(
            width: 24,
            child: Text(
              '$turnNumber',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // プレイヤー1のカード情報
          Expanded(
            child: _buildPlayerCardInfo(
              player1Element,
              player1Power,
              player1FinalPower,
              typeWeakness[player1Element] == player2Element,
            ),
          ),

          // VS
          const SizedBox(width: 4),
          const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),

          // プレイヤー2のカード情報
          Expanded(
            child: _buildPlayerCardInfo(
              player2Element,
              player2Power,
              player2FinalPower,
              typeWeakness[player2Element] == player1Element,
            ),
          ),

          // 結果
          SizedBox(
            width: 100,
            child: Text(
              result,
              style: TextStyle(color: resultColor, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCardInfo(
    String element,
    int basePower,
    int finalPower,
    bool hasWeakness,
  ) {
    Color typeColor;

    switch (element) {
      case 'IT':
        typeColor = Colors.blue;
        break;
      case '語学':
        typeColor = Colors.green;
        break;
      case 'ビジネス':
        typeColor = Colors.red;
        break;
      default:
        typeColor = Colors.grey;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: typeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            element,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        Text('$basePower', style: const TextStyle(fontSize: 12)),
        if (hasWeakness) ...[
          const SizedBox(width: 2),
          const Icon(Icons.arrow_forward, size: 12),
          const SizedBox(width: 2),
          Text(
            '$finalPower',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
