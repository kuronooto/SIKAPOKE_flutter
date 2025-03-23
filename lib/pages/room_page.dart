import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  // ゲーム状態
  int turn = 1;
  int player1Points = 0;
  int player2Points = 0;
  int player1OMP = 0;
  int player2OMP = 0;

  // カード選択
  int? selectedCardId;
  int? opponentCardId;
  Map<String, dynamic>? selectedCardData;
  Map<String, dynamic>? opponentCardData;
  bool isWaitingForOpponent = false;
  bool isTurnProcessing = false;

  // プレイヤー情報
  List<int> playerDeck = [];
  List<Map<String, dynamic>> deckCards = [];
  bool isPlayer1 = false;

  // 勝敗判定関連
  final Map<String, String> typeWeakness = {
    "IT": "語学",
    "語学": "ビジネス",
    "ビジネス": "IT",
  };

  // バトルログ
  List<BattleLogItem> battleLogs = [];

  @override
  void initState() {
    super.initState();
    _initializeGameState();
    _fetchPlayerDeck();
    _listenToGameState();
  }

  void _initializeGameState() {
    // 初期化時に現在のゲーム状態を反映
    if (widget.gameState.isNotEmpty) {
      setState(() {
        turn = widget.gameState['turn'] ?? 1;
        player1Points = widget.gameState['player1_point'] ?? 0;
        player2Points = widget.gameState['player2_point'] ?? 0;
        player1OMP = widget.gameState['player1_over_mount'] ?? 0;
        player2OMP = widget.gameState['player2_over_mount'] ?? 0;
      });
    }

    // 自分がプレイヤー1かプレイヤー2かを判定
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == widget.player1Id) {
      isPlayer1 = true;
    }
  }

  Future<void> _fetchPlayerDeck() async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid);

      final userSnapshot = await userRef.get();

      if (userSnapshot.exists) {
        final deckData = userSnapshot.data()?['deck'];
        if (deckData != null) {
          setState(() {
            playerDeck = List<int>.from(deckData);
          });

          // デッキの各カードの情報を取得
          for (var cardId in playerDeck) {
            if (cardId > 0) {
              final cardSnapshot =
                  await FirebaseFirestore.instance
                      .collection('cards')
                      .where('id', isEqualTo: cardId)
                      .limit(1)
                      .get();

              if (cardSnapshot.docs.isNotEmpty) {
                deckCards.add(cardSnapshot.docs.first.data());
              }
            }
          }

          setState(() {});
        }
      }
    } catch (e) {
      print('デッキ取得エラー: $e');
    }
  }

  void _listenToGameState() {
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);

    roomRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        // ルームが削除された場合は画面を閉じる
        Navigator.of(context).pop();
        return;
      }

      final data = snapshot.data();

      if (data != null) {
        final gameState = data['game_state'] as Map<String, dynamic>;

        setState(() {
          turn = gameState['turn'] ?? turn;
          player1Points = gameState['player1_point'] ?? player1Points;
          player2Points = gameState['player2_point'] ?? player2Points;
          player1OMP = gameState['player1_over_mount'] ?? player1OMP;
          player2OMP = gameState['player2_over_mount'] ?? player2OMP;

          // 相手のカード選択を反映
          if (isPlayer1 && gameState['player2_card'] != null) {
            opponentCardId = gameState['player2_card'];
          } else if (!isPlayer1 && gameState['player1_card'] != null) {
            opponentCardId = gameState['player1_card'];
          }
        });

        // 両プレイヤーがカードを選択した時
        if (gameState['player1_card'] != null &&
            gameState['player2_card'] != null &&
            !isTurnProcessing) {
          setState(() {
            isTurnProcessing = true;
          });

          // カード情報を取得
          final player1CardData = await _fetchCardData(
            gameState['player1_card'],
          );
          final player2CardData = await _fetchCardData(
            gameState['player2_card'],
          );

          setState(() {
            if (isPlayer1) {
              selectedCardData = player1CardData;
              opponentCardData = player2CardData;
            } else {
              selectedCardData = player2CardData;
              opponentCardData = player1CardData;
            }
          });

          // ターン結果を処理
          _processTurn(player1CardData, player2CardData);
        }

        // カードが両方nullになった場合（次のターン準備完了）
        if (gameState['player1_card'] == null &&
            gameState['player2_card'] == null) {
          setState(() {
            selectedCardId = null;
            opponentCardId = null;
            selectedCardData = null;
            opponentCardData = null;
            isWaitingForOpponent = false;
            isTurnProcessing = false;
          });
        }
      }
    });
  }

  Future<Map<String, dynamic>> _fetchCardData(int cardId) async {
    try {
      final cardSnapshot =
          await FirebaseFirestore.instance
              .collection('cards')
              .where('id', isEqualTo: cardId)
              .limit(1)
              .get();

      if (cardSnapshot.docs.isNotEmpty) {
        return cardSnapshot.docs.first.data();
      }
    } catch (e) {
      print('カード情報取得エラー: $e');
    }

    // デフォルト値
    return {
      'id': cardId,
      'name': 'カード #$cardId',
      'type': 'unknown',
      'power': 0,
      'rank': 'E',
    };
  }

  void _processTurn(
    Map<String, dynamic> player1CardData,
    Map<String, dynamic> player2CardData,
  ) async {
    final player1CardPower = player1CardData['power'] as int? ?? 0;
    final player2CardPower = player2CardData['power'] as int? ?? 0;

    final player1CardType = player1CardData['type'] as String? ?? '';
    final player2CardType = player2CardData['type'] as String? ?? '';

    // 相性による倍率を計算
    int player1FinalPower = player1CardPower;
    int player2FinalPower = player2CardPower;

    bool player1HasTypeAdvantage = false;
    bool player2HasTypeAdvantage = false;

    if (typeWeakness[player1CardType] == player2CardType) {
      player1FinalPower *= 2;
      player1HasTypeAdvantage = true;
    }

    if (typeWeakness[player2CardType] == player1CardType) {
      player2FinalPower *= 2;
      player2HasTypeAdvantage = true;
    }

    // 勝敗を判定
    String turnResult = '';
    int player1PointsDelta = 0;
    int player2PointsDelta = 0;
    int player1OMPDelta = 0;
    int player2OMPDelta = 0;

    if (player1FinalPower > player2FinalPower) {
      player1PointsDelta = 1;
      player2OMPDelta = player1FinalPower - player2FinalPower;
      turnResult = 'プレイヤー1の勝ち';
    } else if (player1FinalPower < player2FinalPower) {
      player2PointsDelta = 1;
      player1OMPDelta = player2FinalPower - player1FinalPower;
      turnResult = 'プレイヤー2の勝ち';
    } else {
      turnResult = '引き分け';
    }

    // バトルログに追加
    battleLogs.add(
      BattleLogItem(
        turn: turn,
        player1Card: player1CardData['name'] as String? ?? 'カード',
        player2Card: player2CardData['name'] as String? ?? 'カード',
        player1Power: player1CardPower,
        player2Power: player2CardPower,
        player1FinalPower: player1FinalPower,
        player2FinalPower: player2FinalPower,
        player1TypeAdvantage: player1HasTypeAdvantage,
        player2TypeAdvantage: player2HasTypeAdvantage,
        result: turnResult,
      ),
    );

    // バトル結果をアニメーション表示
    await _showBattleResultDialog(
      player1CardData,
      player2CardData,
      player1FinalPower,
      player2FinalPower,
      turnResult,
    );

    // Firestoreを更新
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);

    // 自分がプレイヤー1の場合のみ、ゲームステートを更新
    if (isPlayer1) {
      await roomRef.update({
        'game_state.player1_point': player1Points + player1PointsDelta,
        'game_state.player2_point': player2Points + player2PointsDelta,
        'game_state.player1_over_mount': player1OMP + player1OMPDelta,
        'game_state.player2_over_mount': player2OMP + player2OMPDelta,
        'game_state.turn': turn + 1,
        'game_state.player1_card': null,
        'game_state.player2_card': null,
      });
    }

    // ローカルステートを更新
    setState(() {
      player1Points += player1PointsDelta;
      player2Points += player2PointsDelta;
      player1OMP += player1OMPDelta;
      player2OMP += player2OMPDelta;
    });

    // 勝敗判定
    _checkGameOver();
  }

  Future<void> _showBattleResultDialog(
    Map<String, dynamic> player1Card,
    Map<String, dynamic> player2Card,
    int player1FinalPower,
    int player2FinalPower,
    String result,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('バトル結果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // プレイヤー1のカード
              _buildBattleCardInfo(
                player1Card['name'] as String? ?? '',
                player1Card['type'] as String? ?? '',
                player1Card['power'] as int? ?? 0,
                player1FinalPower,
                '先攻',
              ),

              const SizedBox(height: 16),
              const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // プレイヤー2のカード
              _buildBattleCardInfo(
                player2Card['name'] as String? ?? '',
                player2Card['type'] as String? ?? '',
                player2Card['power'] as int? ?? 0,
                player2FinalPower,
                '後攻',
              ),

              const SizedBox(height: 24),

              // 結果表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      result.contains('1')
                          ? Colors.blue[100]
                          : result.contains('2')
                          ? Colors.red[100]
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBattleCardInfo(
    String name,
    String type,
    int basePower,
    int finalPower,
    String player,
  ) {
    final hasPowerBoost = finalPower > basePower;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            player,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getTypeColor(type),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'パワー: $basePower',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (hasPowerBoost) ...[
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.green,
                    ),
                    Text(
                      ' $finalPower',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      ' (x2)',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _checkGameOver() async {
    String? gameOverResult;
    bool isGameOver = false;

    if (player1Points >= 3) {
      gameOverResult = isPlayer1 ? 'あなたの勝ち！' : '相手の勝ち';
      isGameOver = true;
    } else if (player2Points >= 3) {
      gameOverResult = isPlayer1 ? '相手の勝ち' : 'あなたの勝ち！';
      isGameOver = true;
    } else if (player1OMP > 100) {
      gameOverResult = isPlayer1 ? 'あなたの負け (OMP超過)' : 'あなたの勝ち！ (相手のOMP超過)';
      isGameOver = true;
    } else if (player2OMP > 100) {
      gameOverResult = isPlayer1 ? 'あなたの勝ち！ (相手のOMP超過)' : 'あなたの負け (OMP超過)';
      isGameOver = true;
    }

    if (isGameOver && gameOverResult != null) {
      // 部屋のステータスを 'finished' に更新（プレイヤー1のみ更新する）
      if (isPlayer1) {
        try {
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .update({'room_status': 'finished'});
        } catch (e) {
          print('ゲーム終了状態の更新エラー: $e');
        }
      }

      _showGameOverDialog(gameOverResult);
    }
  }

  void _showGameOverDialog(String result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('ゲーム終了'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                result.contains('勝ち')
                    ? Icons.emoji_events
                    : Icons.sentiment_dissatisfied,
                size: 64,
                color: result.contains('勝ち') ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                result,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'スコア: ${isPlayer1 ? player1Points : player2Points} - ${isPlayer1 ? player2Points : player1Points}',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
                Navigator.of(context).pop(); // ルームページを閉じる
              },
              child: const Text('終了する'),
            ),
          ],
        );
      },
    );
  }

  // カードの種類に応じた色を返す
  Color _getTypeColor(String type) {
    switch (type) {
      case 'IT':
        return Colors.blue;
      case 'ビジネス':
        return Colors.green;
      case '語学':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _selectCard(int cardId, Map<String, dynamic> cardData) async {
    if (isWaitingForOpponent || isTurnProcessing || selectedCardId != null) {
      return;
    }

    setState(() {
      selectedCardId = cardId;
      selectedCardData = cardData;
      isWaitingForOpponent = true;
    });

    // Firestore に選択したカードを送信
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);

    if (isPlayer1) {
      await roomRef.update({'game_state.player1_card': cardId});
    } else {
      await roomRef.update({'game_state.player2_card': cardId});
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 戻るボタンを無効化
      child: Scaffold(
        appBar: AppBar(
          title: const Text('対戦ルーム'),
          backgroundColor: Colors.blueGrey[700],
          automaticallyImplyLeading: false, // 戻るボタンを非表示
          actions: [
            // バトルログボタン
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                _showBattleLogDialog();
              },
              tooltip: 'バトルログ',
            ),
            // 退出ボタン（緊急用）
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () {
                _showExitConfirmDialog();
              },
              tooltip: '退出',
            ),
          ],
        ),
        body: Column(
          children: [
            // 上部：スコアとステータス表示
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPlayerInfo(
                        isPlayer1 ? 'あなた' : '相手',
                        isPlayer1 ? player1Points : player2Points,
                        isPlayer1 ? player1OMP : player2OMP,
                        isPlayer1 ? Colors.blue : Colors.red,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
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
                            const Text('ターン'),
                            Text(
                              '$turn',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildPlayerInfo(
                        isPlayer1 ? '相手' : 'あなた',
                        isPlayer1 ? player2Points : player1Points,
                        isPlayer1 ? player2OMP : player1OMP,
                        isPlayer1 ? Colors.red : Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 状態表示
                  if (isWaitingForOpponent && selectedCardId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.amber,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('相手の選択を待っています...'),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 中部：選択したカードと相手のカード表示
            if (selectedCardId != null || opponentCardId != null)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selectedCardId != null && selectedCardData != null)
                      Expanded(
                        child: _buildSelectedCardDisplay(
                          selectedCardData!,
                          '選択中のカード',
                        ),
                      ),
                    if (selectedCardId != null && opponentCardId != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (opponentCardId != null && opponentCardData != null)
                      Expanded(
                        child: _buildSelectedCardDisplay(
                          opponentCardData!,
                          '相手のカード',
                        ),
                      ),
                    if (opponentCardId != null && opponentCardData == null)
                      const Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                '相手がカードを選択しました',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // 下部：カード選択エリア
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        selectedCardId != null ? 'カード選択済み' : 'カードを選択してください',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // カード一覧
                    Expanded(
                      child:
                          deckCards.isEmpty
                              ? const Center(child: Text('デッキが空です'))
                              : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1.5,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                itemCount: deckCards.length,
                                itemBuilder: (context, index) {
                                  final card = deckCards[index];
                                  final cardId = card['id'] as int;

                                  return _buildSelectableCard(
                                    card,
                                    isSelected: selectedCardId == cardId,
                                    onSelect: () => _selectCard(cardId, card),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfo(String title, int points, int omp, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('勝利:'),
              const SizedBox(width: 4),
              Text(
                '$points',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('OMP:'),
              const SizedBox(width: 4),
              Text(
                '$omp',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color:
                      omp > 75
                          ? Colors.red
                          : (omp > 50 ? Colors.orange : Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCardDisplay(Map<String, dynamic> card, String label) {
    final cardName = card['name'] as String? ?? 'カード';
    final cardPower = card['power'] as int? ?? 0;
    final cardType = card['type'] as String? ?? '';
    final cardRank = card['rank'] as String? ?? '';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _getTypeColor(cardType), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              cardName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(cardType),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cardType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ランク$cardRank',
                    style: TextStyle(color: Colors.grey[800], fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'パワー: $cardPower',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableCard(
    Map<String, dynamic> card, {
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    final cardName = card['name'] as String? ?? 'カード';
    final cardPower = card['power'] as int? ?? 0;
    final cardType = card['type'] as String? ?? '';

    return InkWell(
      onTap:
          isWaitingForOpponent || isTurnProcessing || selectedCardId != null
              ? null
              : onSelect,
      child: Card(
        elevation: isSelected ? 8 : 2,
        color: isSelected ? Colors.blue[50] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(cardType),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cardType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    'P$cardPower',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  cardName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '選択中',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBattleLogDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('バトルログ'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  battleLogs.isEmpty
                      ? const Center(child: Text('まだログはありません'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: battleLogs.length,
                        itemBuilder: (context, index) {
                          final log = battleLogs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ターン ${log.turn}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Divider(),
                                  Text(
                                    '先攻: ${log.player1Card} (パワー:${log.player1FinalPower})',
                                  ),
                                  Text(
                                    '後攻: ${log.player2Card} (パワー:${log.player2FinalPower})',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '結果: ${log.result}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          log.result.contains('1')
                                              ? Colors.blue
                                              : log.result.contains('2')
                                              ? Colors.red
                                              : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('閉じる'),
              ),
            ],
          ),
    );
  }

  void _showExitConfirmDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('退出の確認'),
            content: const Text('バトルを途中で終了すると、対戦相手にも影響します。本当に退出しますか？'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('退出する'),
              ),
            ],
          ),
    );
  }
}

// バトルログ用のクラス
class BattleLogItem {
  final int turn;
  final String player1Card;
  final String player2Card;
  final int player1Power;
  final int player2Power;
  final int player1FinalPower;
  final int player2FinalPower;
  final bool player1TypeAdvantage;
  final bool player2TypeAdvantage;
  final String result;

  BattleLogItem({
    required this.turn,
    required this.player1Card,
    required this.player2Card,
    required this.player1Power,
    required this.player2Power,
    required this.player1FinalPower,
    required this.player2FinalPower,
    required this.player1TypeAdvantage,
    required this.player2TypeAdvantage,
    required this.result,
  });
}
