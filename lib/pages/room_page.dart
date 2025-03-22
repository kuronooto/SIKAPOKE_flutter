import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import './battle/widgets/card_widget.dart';
import './battle/widgets/battle_log_widget.dart';

class RoomPage extends StatefulWidget {
  final String roomId;
  final String player1Id;
  final String? player2Id;
  final Map<String, dynamic> gameState;

  const RoomPage({
    super.key,
    required this.roomId,
    required this.player1Id,
    this.player2Id,
    required this.gameState,
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
  bool isTurnProcessing = false;
  List<int> playerDeck = [];
  String currentUserId = '';
  bool isPlayer1 = false;
  Map<int, Map<String, dynamic>> cardDataCache = {};
  Map<String, dynamic> logs = {'player1_log': {}, 'player2_log': {}};
  bool isGameOver = false;
  String gameResult = '';

  // アニメーション用
  bool showBattleAnimation = false;
  Map<String, dynamic>? player1CardData;
  Map<String, dynamic>? player2CardData;
  String turnResult = '';

  // タイマー関連
  int turnTimeLimit = 30; // 30秒
  int turnTimeRemaining = 30;
  Timer? turnTimer;

  final Map<String, String> typeWeakness = {
    "IT": "語学",
    "語学": "ビジネス",
    "ビジネス": "IT",
  };

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    isPlayer1 = currentUserId == widget.player1Id;
    _loadInitialData();
    _listenToGameState();
    _listenToLogs();
    _startTurnTimer();
  }

  @override
  void dispose() {
    turnTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _fetchPlayerDeck();

    // 既存のゲーム状態を読み込む
    turn = widget.gameState['turn'] ?? 1;
    player1Points = widget.gameState['player1_point'] ?? 0;
    player2Points = widget.gameState['player2_point'] ?? 0;
    player1OMP = widget.gameState['player1_over_mount'] ?? 0;
    player2OMP = widget.gameState['player2_over_mount'] ?? 0;

    // すべてのカードデータを事前にロード
    await _preloadCardData();
  }

  Future<void> _preloadCardData() async {
    // プレイヤーデッキのカードデータをプリロード
    for (int cardId in playerDeck) {
      if (!cardDataCache.containsKey(cardId)) {
        final data = await _fetchCardData(cardId);
        if (data.isNotEmpty) {
          cardDataCache[cardId] = data;
        }
      }
    }
  }

  void _startTurnTimer() {
    turnTimer?.cancel();
    setState(() {
      turnTimeRemaining = turnTimeLimit;
    });

    turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (turnTimeRemaining > 0) {
          turnTimeRemaining--;
        } else {
          _handleTimeOut();
          timer.cancel();
        }
      });
    });
  }

  void _handleTimeOut() {
    if (selectedCardId == null && !isWaitingForOpponent && !isTurnProcessing) {
      // 時間切れでランダムなカードを選択
      if (playerDeck.isNotEmpty) {
        final randomIndex =
            DateTime.now().millisecondsSinceEpoch % playerDeck.length;
        _selectCard(playerDeck[randomIndex]);
      }
    }
  }

  Future<void> _fetchPlayerDeck() async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId);
    final userSnapshot = await userRef.get();
    if (userSnapshot.exists) {
      setState(() {
        playerDeck = List<int>.from(userSnapshot.data()?['deck'] ?? []);
      });
    }
  }

  Future<Map<String, dynamic>> _fetchCardData(int cardId) async {
    // キャッシュから取得できる場合はキャッシュを返す
    if (cardDataCache.containsKey(cardId)) {
      return cardDataCache[cardId]!;
    }

    final cardRef = FirebaseFirestore.instance
        .collection('cards')
        .doc(cardId.toString());
    final cardSnapshot = await cardRef.get();
    if (cardSnapshot.exists) {
      final data = cardSnapshot.data() ?? {};
      cardDataCache[cardId] = data; // キャッシュに保存
      return data;
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

        setState(() {
          turn = gameState['turn'] ?? turn;
          player1Points = gameState['player1_point'] ?? player1Points;
          player2Points = gameState['player2_point'] ?? player2Points;
          player1OMP = gameState['player1_over_mount'] ?? player1OMP;
          player2OMP = gameState['player2_over_mount'] ?? player2OMP;

          // 現在のプレイヤーのカード状態を更新
          if (isPlayer1) {
            selectedCardId = gameState['player1_card'];
            opponentCardId = gameState['player2_card'];
          } else {
            selectedCardId = gameState['player2_card'];
            opponentCardId = gameState['player1_card'];
          }

          isWaitingForOpponent =
              selectedCardId != null && opponentCardId == null;
        });

        // 両方のプレイヤーがカードを選択した場合、ターンを処理
        if (gameState['player1_card'] != null &&
            gameState['player2_card'] != null &&
            !isTurnProcessing) {
          isTurnProcessing = true;
          await _processTurnWithAnimation(
            gameState['player1_card'],
            gameState['player2_card'],
          );
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
        setState(() {
          logs = data['logs'] as Map<String, dynamic>;
        });
      }
    });
  }

  Future<void> _processTurnWithAnimation(
    int player1CardId,
    int player2CardId,
  ) async {
    // アニメーション用にカードデータを取得
    player1CardData = await _fetchCardData(player1CardId);
    player2CardData = await _fetchCardData(player2CardId);

    // バトルアニメーションを表示
    setState(() {
      showBattleAnimation = true;
    });

    // 3秒間アニメーションを表示
    await Future.delayed(const Duration(seconds: 3));

    // アニメーションを非表示にし、実際の処理を行う
    setState(() {
      showBattleAnimation = false;
    });

    // サーバーサイドでの勝敗処理
    final player1CardPower = player1CardData?['power'] as int? ?? 0;
    final player2CardPower = player2CardData?['power'] as int? ?? 0;

    final player1CardType = player1CardData?['type'] as String? ?? '';
    final player2CardType = player2CardData?['type'] as String? ?? '';

    int player1FinalPower = player1CardPower;
    int player2FinalPower = player2CardPower;

    if (typeWeakness[player1CardType] == player2CardType) {
      player1FinalPower *= 2;
    }
    if (typeWeakness[player2CardType] == player1CardType) {
      player2FinalPower *= 2;
    }

    // 勝敗を判定し、Firestore 上のポイントを更新
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);

    if (player1FinalPower > player2FinalPower) {
      player1Points++;
      player2OMP += player1FinalPower - player2FinalPower;
      turnResult = isPlayer1 ? "あなたの勝ち!" : "あなたの負け!";
      await roomRef.update({
        'game_state.player1_point': player1Points,
        'game_state.player2_over_mount': player2OMP,
      });
    } else if (player1FinalPower < player2FinalPower) {
      player2Points++;
      player1OMP += player2FinalPower - player1FinalPower;
      turnResult = isPlayer1 ? "あなたの負け!" : "あなたの勝ち!";
      await roomRef.update({
        'game_state.player2_point': player2Points,
        'game_state.player1_over_mount': player1OMP,
      });
    } else {
      turnResult = "引き分け!";
    }

    // 自分が player1 の場合のみターンを進める
    if (isPlayer1) {
      await roomRef.update({
        'game_state.turn': turn + 1,
        'game_state.player1_card': null,
        'game_state.player2_card': null,
      });
    }

    setState(() {
      selectedCardId = null;
      opponentCardId = null;
      isTurnProcessing = false;
    });

    // ターンタイマーをリセット
    _startTurnTimer();

    // 勝敗判定
    _checkGameOver();
  }

  void _checkGameOver() {
    if (player1Points >= 3) {
      _showGameOverDialog(isPlayer1 ? 'あなたの勝ち!' : 'あなたの負け!');
    } else if (player2Points >= 3) {
      _showGameOverDialog(isPlayer1 ? 'あなたの負け!' : 'あなたの勝ち!');
    } else if (player1OMP > 100) {
      _showGameOverDialog(isPlayer1 ? 'あなたの負け! (OMP超過)' : 'あなたの勝ち! (OMP超過)');
    } else if (player2OMP > 100) {
      _showGameOverDialog(isPlayer1 ? 'あなたの勝ち! (相手のOMP超過)' : 'あなたの負け! (OMP超過)');
    }
  }

  void _showGameOverDialog(String result) {
    setState(() {
      isGameOver = true;
      gameResult = result;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            result,
            style: TextStyle(
              color: result.contains('勝ち') ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(
                '最終スコア',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        'プレイヤー 1',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('ポイント: $player1Points'),
                      Text('OMP: $player1OMP'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'プレイヤー 2',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('ポイント: $player2Points'),
                      Text('OMP: $player2OMP'),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // ルーム画面を閉じてバトルページに戻る
              },
              child: const Text('終了'),
            ),
          ],
        );
      },
    );
  }

  void _selectCard(int cardId) async {
    // カードが既に選択されている場合や処理中の場合は何もしない
    if (isWaitingForOpponent || isTurnProcessing || isGameOver) return;

    setState(() {
      selectedCardId = cardId;
      isWaitingForOpponent = true;
    });

    // Firestore に選択したカードを送信
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);

    // カード情報を取得
    final cardData = await _fetchCardData(cardId);
    final cardType = cardData['type'] as String? ?? '';
    final cardPower = cardData['power'] as int? ?? 0;

    // 自分のカード情報を更新
    if (isPlayer1) {
      await roomRef.update({
        'game_state.player1_card': cardId,
        'logs.player1_log.element': FieldValue.arrayUnion([cardType]),
        'logs.player1_log.power': FieldValue.arrayUnion([cardPower]),
      });
    } else {
      await roomRef.update({
        'game_state.player2_card': cardId,
        'logs.player2_log.element': FieldValue.arrayUnion([cardType]),
        'logs.player2_log.power': FieldValue.arrayUnion([cardPower]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 戻るボタンを無効化
      child: Scaffold(
        appBar: AppBar(
          title: const Text('バトルルーム'),
          centerTitle: true,
          automaticallyImplyLeading: false, // AppBarの戻るボタンを非表示
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // 上部: ステータスバー
                _buildStatusBar(),

                // 中央: バトルエリア
                Expanded(
                  child: Column(
                    children: [
                      // 相手のエリア
                      _buildOpponentArea(),

                      // 中央: バトルログ
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: BattleLogWidget(logs: logs, turn: turn),
                          ),
                        ),
                      ),

                      // プレイヤーのエリア
                      _buildPlayerArea(),
                    ],
                  ),
                ),
              ],
            ),

            // バトルアニメーションのオーバーレイ
            if (showBattleAnimation) _buildBattleAnimation(),

            // ゲームオーバー時のオーバーレイ
            if (isGameOver) _buildGameOverOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // プレイヤー1情報
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'プレイヤー 1',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPlayer1 ? Colors.blue : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Text('ポイント: $player1Points'),
                  Text(
                    'OMP: $player1OMP',
                    style: TextStyle(
                      color: player1OMP > 80 ? Colors.red : Colors.black,
                      fontWeight:
                          player1OMP > 80 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              // ターン情報
              Column(
                children: [
                  Text(
                    'ターン $turn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: turnTimeRemaining < 10 ? Colors.red : Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$turnTimeRemaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // プレイヤー2情報
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        'プレイヤー 2',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !isPlayer1 ? Colors.red : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Text('ポイント: $player2Points'),
                  Text(
                    'OMP: $player2OMP',
                    style: TextStyle(
                      color: player2OMP > 80 ? Colors.red : Colors.black,
                      fontWeight:
                          player2OMP > 80 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentArea() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey.shade100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '相手のカード',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: Center(
              child:
                  opponentCardId != null
                      ? CardWidget(
                        cardId: opponentCardId!,
                        cardData:
                            showBattleAnimation || isTurnProcessing
                                ? isPlayer1
                                    ? player2CardData
                                    : player1CardData
                                : null,
                        isRevealed: showBattleAnimation || isTurnProcessing,
                        isOpponent: true,
                      )
                      : const Text('相手はまだカードを選択していません'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'あなたのデッキ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (selectedCardId != null)
                Text(
                  '選択中: カード ${playerDeck.indexOf(selectedCardId!) + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child:
                playerDeck.isEmpty
                    ? const Center(child: Text('デッキが空です'))
                    : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: playerDeck.length,
                      itemBuilder: (context, index) {
                        final cardId = playerDeck[index];
                        final isSelected = selectedCardId == cardId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CardWidget(
                            cardId: cardId,
                            cardData: cardDataCache[cardId],
                            isSelected: isSelected,
                            onTap:
                                (isWaitingForOpponent ||
                                        isTurnProcessing ||
                                        isGameOver)
                                    ? null
                                    : () => _selectCard(cardId),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattleAnimation() {
    // タイプ相性による倍率を計算
    final player1CardType = player1CardData?['type'] as String? ?? '';
    final player2CardType = player2CardData?['type'] as String? ?? '';
    final player1CardPower = player1CardData?['power'] as int? ?? 0;
    final player2CardPower = player2CardData?['power'] as int? ?? 0;

    int player1FinalPower = player1CardPower;
    int player2FinalPower = player2CardPower;

    if (typeWeakness[player1CardType] == player2CardType) {
      player1FinalPower *= 2;
    }
    if (typeWeakness[player2CardType] == player1CardType) {
      player2FinalPower *= 2;
    }

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'バトル!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.red,
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    CardWidget(
                      cardId: player1CardData?['id'] as int? ?? 0,
                      cardData: player1CardData,
                      isRevealed: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      player1FinalPower.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.blue,
                            blurRadius: 10,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  children: [
                    CardWidget(
                      cardId: player2CardData?['id'] as int? ?? 0,
                      cardData: player2CardData,
                      isRevealed: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      player2FinalPower.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.red,
                            blurRadius: 10,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ゲーム終了',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                gameResult,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: gameResult.contains('勝ち') ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text('ルームを退出する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
