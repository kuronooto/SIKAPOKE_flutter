import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class RoomPage extends StatefulWidget {
  final String roomId;
  final String player1Id;
  final String? player2Id;
  final Map<String, dynamic> gameState; // Add gameState parameter

  const RoomPage({
    super.key,
    required this.roomId,
    required this.player1Id,
    this.player2Id,
    required this.gameState, // Include gameState in the constructor
  });

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  int turn = 1;
  int player1Points = 0;
  int player2Points = 0;
  int player1OMP = 0;
  int player2OMP = 0;
  int? selectedCardId;
  int? opponentCardId;
  bool isWaitingForOpponent = false;
  bool isTurnProcessing = false; // ターン処理中フラグ
  List<int> playerDeck = []; // プレイヤーのデッキ

  final Map<String, String> typeWeakness = {
    "IT": "語学",
    "語学": "ビジネス",
    "ビジネス": "IT",
  };

  @override
  void initState() {
    super.initState();
    _fetchPlayerDeck();
    _listenToGameState();
    _listenToLogs(); // logs の監視を開始
  }

  Future<void> _fetchPlayerDeck() async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.player1Id);
    final userSnapshot = await userRef.get();
    if (userSnapshot.exists) {
      setState(() {
        playerDeck = List<int>.from(userSnapshot.data()?['deck'] ?? []);
      });
    }
  }

  Future<Map<String, dynamic>> _fetchCardData(int cardId) async {
    final cardRef = FirebaseFirestore.instance
        .collection('cards')
        .doc(cardId.toString());
    final cardSnapshot = await cardRef.get();
    if (cardSnapshot.exists) {
      return cardSnapshot.data() ?? {};
    }
    return {};
  }

  void _listenToGameState() {
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    roomRef.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data != null) {
        final gameState = data['game_state'] as Map<String, dynamic>;
        final logs = data['logs'] as Map<String, dynamic>;

        setState(() {
          turn = gameState['turn'];
          player1Points = gameState['player1_point'];
          player2Points = gameState['player2_point'];
          player1OMP = gameState['player1_over_mount'];
          player2OMP = gameState['player2_over_mount'];
        });

        // 両方のプレイヤーがカードを選択した場合、ターンを処理
        if (gameState['player1_card'] != null &&
            gameState['player2_card'] != null &&
            !isTurnProcessing) {
          isTurnProcessing = true; // ターン処理中フラグを設定
          final player1CardData = await _fetchCardData(
            gameState['player1_card'],
          );
          final player2CardData = await _fetchCardData(
            gameState['player2_card'],
          );
          _processTurn(player1CardData, player2CardData, logs);
        }
      }
    });
  }

  void _listenToLogs() {
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    roomRef.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        final logs = data['logs'] as Map<String, dynamic>;

        // logs の変更を反映
        print('Logs updated: $logs');
        // 必要に応じて logs を UI に反映させる処理を追加
      }
    });
  }

  void _processTurn(
    Map<String, dynamic> player1CardData,
    Map<String, dynamic> player2CardData,
    Map<String, dynamic> logs,
  ) async {
    final player1CardPower = player1CardData['power'] as int? ?? 0;
    final player2CardPower = player2CardData['power'] as int? ?? 0;

    final player1CardType = player1CardData['type'] as String? ?? '';
    final player2CardType = player2CardData['type'] as String? ?? '';

    int player1FinalPower = player1CardPower;
    int player2FinalPower = player2CardPower;

    if (typeWeakness[player1CardType] == player2CardType) {
      player1FinalPower *= 2;
    }
    if (typeWeakness[player2CardType] == player1CardType) {
      player2FinalPower *= 2;
    }

    // 勝敗を判定し、Firestore 上のポイントとログを更新
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    if (player1FinalPower > player2FinalPower) {
      player1Points++;
      player2OMP += player1FinalPower - player2FinalPower;
      await roomRef.update({
        'game_state.player1_point': player1Points,
        'game_state.player2_over_mount': player2OMP,
      });
    } else if (player1FinalPower < player2FinalPower) {
      player2Points++;
      player1OMP += player2FinalPower - player1FinalPower;
      await roomRef.update({
        'game_state.player2_point': player2Points,
        'game_state.player1_over_mount': player1OMP,
      });
    }

    // 自分のカード情報をログに格納
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == widget.player1Id) {
      await roomRef.update({
        'logs.player1_log.power': FieldValue.arrayUnion([player1CardPower]),
        'logs.player1_log.type': FieldValue.arrayUnion([player1CardType]),
      });
    } else {
      await roomRef.update({
        'logs.player2_log.power': FieldValue.arrayUnion([player2CardPower]),
        'logs.player2_log.type': FieldValue.arrayUnion([player2CardType]),
      });
    }

    // 自分が player1 の場合のみターンを進める
    if (currentUserId == widget.player1Id) {
      await roomRef.update({
        'game_state.turn': turn + 1,
        'game_state.player1_card': null,
        'game_state.player2_card': null,
      });
    }

    setState(() {
      selectedCardId = null;
      opponentCardId = null;
      isTurnProcessing = false; // ターン処理中フラグを解除
    });

    // 勝敗判定
    _checkGameOver();
  }

  void _checkGameOver() {
    if (player1Points >= 3) {
      _showGameOverDialog('You Win!');
    } else if (player2Points >= 3) {
      _showGameOverDialog('You Lose!');
    } else if (player1OMP > 100) {
      _showGameOverDialog('You Lose! (OMP Over)');
    } else if (player2OMP > 100) {
      _showGameOverDialog('You Win! (Opponent OMP Over)');
    }
  }

  void _showGameOverDialog(String result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(result),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 戻るボタンを無効化
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Room Page'),
          automaticallyImplyLeading: false, // AppBarの戻るボタンを非表示
        ),
        body: Column(
          children: [
            // 上部: ターン数、ポイント、OMP
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text('Player 1 Points: $player1Points'),
                      Text('Player 1 OMP: $player1OMP'),
                    ],
                  ),
                  Text('Turn: $turn'),
                  Column(
                    children: [
                      Text('Player 2 Points: $player2Points'),
                      Text('Player 2 OMP: $player2OMP'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // 中央: 選択したカードと相手のカード
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selectedCardId != null)
                      Text('Your Card: $selectedCardId'),
                    if (opponentCardId != null)
                      Text('Opponent Card: $opponentCardId'),
                  ],
                ),
              ),
            ),
            const Divider(),
            // 下部: カード選択
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(playerDeck.length, (index) {
                  return ElevatedButton(
                    onPressed:
                        isWaitingForOpponent || isTurnProcessing
                            ? null
                            : () => _selectCard(playerDeck[index]),
                    child: Text('Card ${index + 1}'),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCard(int cardId) async {
    setState(() {
      selectedCardId = cardId;
      isWaitingForOpponent = true;
    });

    // Firestore に選択したカードを送信
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    await roomRef.update({
      'game_state.player1_card':
          widget.player1Id == widget.player1Id ? cardId : null,
      'game_state.player2_card':
          widget.player1Id == widget.player2Id ? cardId : null,
    });
  }
}
