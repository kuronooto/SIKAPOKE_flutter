import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/common/card.dart';

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

    Future.delayed(const Duration(milliseconds: 500), () {
      _showPlayerInfoDialog();
    });
  }

  @override
  void dispose() {
    // 部屋から退出時に処理（相手がいない場合は部屋を削除）
    _handleRoomExit();
    super.dispose();
  }

  Future<void> _handleRoomExit() async {
    try {
      final roomRef = FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId);

      final roomSnapshot = await roomRef.get();
      if (!roomSnapshot.exists) return;

      final data = roomSnapshot.data();
      if (data == null) return;

      // 部屋のステータスが 'finished' なら何もしない
      if (data['room_status'] == 'finished') return;

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // 部屋の状態に応じて処理
      if (currentUserId == widget.player1Id) {
        // 相手がいなければ削除、いれば自分のIDをnullに
        if (data['player2_id'] == null) {
          await roomRef.delete();
          print('Player1が退出: 部屋を削除しました');
        } else {
          await roomRef.update({
            'player1_id': null,
            'room_status': 'player1_left',
          });
          print('Player1が退出: player1_idをnullに設定');
        }
      } else if (currentUserId == widget.player2Id) {
        // 相手がいなければ削除、いれば自分のIDをnullに
        if (data['player1_id'] == null) {
          await roomRef.delete();
          print('Player2が退出: 部屋を削除しました');
        } else {
          await roomRef.update({
            'player2_id': null,
            'room_status': 'player2_left',
          });
          print('Player2が退出: player2_idをnullに設定');
        }
      }
    } catch (e) {
      print('部屋の退出処理エラー: $e');
    }
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

    roomRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        // ルームが削除された場合は画面を閉じる
        print('ルームが存在しません: ${widget.roomId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('対戦が終了しました。相手が退出した可能性があります。')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final data = snapshot.data();

      if (data != null) {
        final gameState = data['game_state'] as Map<String, dynamic>;

        // 重要: Firestoreのデータを常に信頼し、ローカルステートを上書きする
        final newPlayer1Points = gameState['player1_point'] as int? ?? 0;
        final newPlayer2Points = gameState['player2_point'] as int? ?? 0;
        final newPlayer1OMP = gameState['player1_over_mount'] as int? ?? 0;
        final newPlayer2OMP = gameState['player2_over_mount'] as int? ?? 0;
        final newTurn = gameState['turn'] as int? ?? 1;

        // 変更があれば出力（デバッグ用）
        if (newPlayer1Points != player1Points ||
            newPlayer2Points != player2Points ||
            newPlayer1OMP != player1OMP ||
            newPlayer2OMP != player2OMP ||
            newTurn != turn) {
          print(
            'ゲーム状態が更新されました: P1=$newPlayer1Points, P2=$newPlayer2Points, P1OMP=$newPlayer1OMP, P2OMP=$newPlayer2OMP, Turn=$newTurn',
          );
        }

        // 必ずFirestoreの値でローカルステートを更新
        setState(() {
          turn = newTurn;
          player1Points = newPlayer1Points;
          player2Points = newPlayer2Points;
          player1OMP = newPlayer1OMP;
          player2OMP = newPlayer2OMP;

          // 相手のカード選択を反映
          if (isPlayer1 && gameState['player2_card'] != null) {
            opponentCardId = gameState['player2_card'];
          } else if (!isPlayer1 && gameState['player1_card'] != null) {
            opponentCardId = gameState['player1_card'];
          }
        });

        // スコアを確認して勝敗判定を行う（両プレイヤー側で実行）
        if (player1Points >= 3 ||
            player2Points >= 3 ||
            player1OMP > 150 ||
            player2OMP > 150) {
          print(
            '勝敗判定条件を満たしています: P1=$player1Points, P2=$player2Points, P1OMP=$player1OMP, P2OMP=$player2OMP',
          );

          // 勝敗判定の呼び出しを遅延させ、Firestoreの更新が完了するのを待つ
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _checkGameOver();
            }
          });
        }

        // 両プレイヤーがカードを選択した時の処理
        if (gameState['player1_card'] != null &&
            gameState['player2_card'] != null &&
            !isTurnProcessing) {
          setState(() {
            isTurnProcessing = true;
          });

          // 非同期処理を別メソッドに分離し、awaitせずに呼び出し
          _handleCardSelection(
            gameState['player1_card'],
            gameState['player2_card'],
          );
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

        // 部屋のステータスをチェック
        if (data['room_status'] == 'finished') {
          print('部屋のステータスが finished になっています');
        }
      }
    });
  }

  // カード選択処理を別メソッドに分離
  void _handleCardSelection(int player1CardId, int player2CardId) async {
    // カード情報を取得
    final player1CardData = await _fetchCardData(player1CardId);
    final player2CardData = await _fetchCardData(player2CardId);

    // カードデータをローカル変数に保持
    Map<String, dynamic> myCard;
    Map<String, dynamic> opponentCard;

    if (isPlayer1) {
      myCard = player1CardData;
      opponentCard = player2CardData;
    } else {
      myCard = player2CardData;
      opponentCard = player1CardData;
    }

    // 状態を更新
    if (mounted) {
      setState(() {
        selectedCardData = myCard;
        opponentCardData = opponentCard;
      });
    }

    // 非同期処理を呼び出し（awaitなし）
    _processTurn(player1CardData, player2CardData);
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
  ) {
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

    // バトル結果をダイアログ表示し、その後にFirestoreを更新する
    _showBattleResultDialog(
      player1CardData,
      player2CardData,
      player1FinalPower,
      player2FinalPower,
      turnResult,
    ).then((_) {
      // ダイアログが閉じられた後の処理
      _updateScoresInFirestore(
        player1PointsDelta,
        player2PointsDelta,
        player1OMPDelta,
        player2OMPDelta,
      );
    });
  }

  // スコアをFirestoreに更新する（_processTurnから切り出した処理）
  void _updateScoresInFirestore(
    int player1PointsDelta,
    int player2PointsDelta,
    int player1OMPDelta,
    int player2OMPDelta,
  ) async {
    // Firestoreを更新（プレイヤー1のみが更新）
    if (isPlayer1) {
      try {
        final roomRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId);

        // 現在の状態を取得して更新（競合を防ぐ）
        final roomSnapshot = await roomRef.get();
        if (!roomSnapshot.exists) return;

        final data = roomSnapshot.data();
        if (data == null) return;

        final currentGameState = data['game_state'] as Map<String, dynamic>;

        // 現在のポイントを取得
        final currentP1Points = currentGameState['player1_point'] as int? ?? 0;
        final currentP2Points = currentGameState['player2_point'] as int? ?? 0;
        final currentP1OMP =
            currentGameState['player1_over_mount'] as int? ?? 0;
        final currentP2OMP =
            currentGameState['player2_over_mount'] as int? ?? 0;

        // 新しい値を計算
        final newP1Points = currentP1Points + player1PointsDelta;
        final newP2Points = currentP2Points + player2PointsDelta;
        final newP1OMP = currentP1OMP + player1OMPDelta;
        final newP2OMP = currentP2OMP + player2OMPDelta;

        print(
          'スコア更新: P1: $currentP1Points → $newP1Points, P2: $currentP2Points → $newP2Points',
        );
        print(
          'OMP更新: P1: $currentP1OMP → $newP1OMP, P2: $currentP2OMP → $newP2OMP',
        );

        // Firestoreを更新
        await roomRef.update({
          'game_state.player1_point': newP1Points,
          'game_state.player2_point': newP2Points,
          'game_state.player1_over_mount': newP1OMP,
          'game_state.player2_over_mount': newP2OMP,
          'game_state.turn': turn + 1,
          'game_state.player1_card': null,
          'game_state.player2_card': null,
        });

        // ローカルステートを更新（Firestoreに合わせる）
        setState(() {
          player1Points = newP1Points;
          player2Points = newP2Points;
          player1OMP = newP1OMP;
          player2OMP = newP2OMP;
        });
      } catch (e) {
        print('Firestore更新エラー: $e');
      }
    }

    // 勝敗判定は_listenToGameState内で行う（両方のクライアントで実行される）
  }

  Future<void> _checkGameOver() async {
    print(
      '勝敗判定: P1=$player1Points, P2=$player2Points, P1OMP=$player1OMP, P2OMP=$player2OMP',
    );
    String? gameOverResult;
    bool isGameOver = false;

    // 勝利条件: 3ポイント先取

    if (player1OMP > 150) {
      gameOverResult = isPlayer1 ? 'あなたの勝ち！ (相手のOMP超過)' : 'あなたの負け！ (あなたのOMP超過)';
      isGameOver = true;
      print('プレイヤー1のOMPが150超過: $player1OMP');
    } else if (player2OMP > 150) {
      gameOverResult = isPlayer1 ? 'あなたの負け！ (あなたのOMP超過)' : 'あなたの勝ち (相手のOMP超過)';
      isGameOver = true;
      print('プレイヤー2のOMPが150超過: $player2OMP');
    }
      else if (player1Points >= 3) {
      gameOverResult = isPlayer1 ? 'あなたの勝ち！' : '相手の勝ち';
      isGameOver = true;
      print('プレイヤー1が3ポイント達成: $player1Points');
    } else if (player2Points >= 3) {
      gameOverResult = isPlayer1 ? '相手の勝ち' : 'あなたの勝ち！';
      isGameOver = true;
      print('プレイヤー2が3ポイント達成: $player2Points');
    }
    
    if (isGameOver && gameOverResult != null) {
      print('ゲーム終了条件を満たしました: $gameOverResult');

      // 重要: プレイヤー1のみがroom_statusをfinishedに更新
      if (isPlayer1) {
        try {
          print('プレイヤー1がroom_statusをfinishedに更新します');

          // 部屋データを取得して現在のステータスを確認
          final roomRef = FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId);

          final roomSnapshot = await roomRef.get();
          if (!roomSnapshot.exists) return;

          final data = roomSnapshot.data();
          if (data == null) return;

          // 部屋が既にfinished状態でなければ更新
          if (data['room_status'] != 'finished') {
            await roomRef.update({
              'room_status': 'finished',
              'winner_id':
                  player1Points >= 3 || player2OMP > 100
                      ? widget.player1Id
                      : widget.player2Id,
              'finished_at': FieldValue.serverTimestamp(),
            });
            print('部屋のステータスをfinishedに更新しました');
          }
        } catch (e) {
          print('ゲーム終了状態の更新エラー: $e');
        }
      }

      // スコア不整合を防ぐための遅延を入れる
      await Future.delayed(const Duration(milliseconds: 300));

      // ゲーム終了ダイアログを表示（この時点でスコアが正しく同期されているはず）
      if (mounted) {
        _showGameOverDialog(gameOverResult);
      }
    } else {
      print('ゲーム継続中: 勝利条件を満たしていません');
    }
  }

  void _showGameOverDialog(String result) {
    if (!mounted) return;

    // 既にダイアログが表示されていないか確認
    bool isDialogShowing = false;
    if (ModalRoute.of(context)?.isCurrent != true) {
      isDialogShowing = true;
    }

    if (isDialogShowing) {
      print('ゲーム終了ダイアログは既に表示されています');
      return;
    }

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

  Future<void> _showBattleResultDialog(
    Map<String, dynamic> player1Card,
    Map<String, dynamic> player2Card,
    int player1FinalPower,
    int player2FinalPower,
    String result,
  ) {
    return showDialog(
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
                'プレイヤー1 ${isPlayer1 ? "(あなた)" : "(相手)"}',
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
                'プレイヤー2 ${!isPlayer1 ? "(あなた)" : "(相手)"}',
              ),

              const SizedBox(height: 24),

              // 結果表示（よりわかりやすく表示）
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      result.contains('1')
                          ? (isPlayer1 ? Colors.green[100] : Colors.red[100])
                          : result.contains('2')
                          ? (!isPlayer1 ? Colors.green[100] : Colors.red[100])
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  // 結果をより直感的に表示
                  result.contains('1')
                      ? (isPlayer1 ? 'あなたの勝ち！' : '相手の勝ち')
                      : result.contains('2')
                      ? (!isPlayer1 ? 'あなたの勝ち！' : '相手の勝ち')
                      : '引き分け',
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

  void _showPlayerInfoDialog() {
    // マッチング後、最初のターン前にプレイヤー情報を表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('対戦情報'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person,
                size: 48,
                color: isPlayer1 ? Colors.blue : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'あなたは ${isPlayer1 ? "プレイヤー1" : "プレイヤー2"} です',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPlayer1 ? Colors.blue : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPlayer1 ? '先攻プレイヤーとして対戦します' : '後攻プレイヤーとして対戦します',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                '勝利条件: 3ポイント先取\nOMPが150を超えると敗北します',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('了解'),
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
                        isPlayer1 ? 'プレイヤー1' : 'プレイヤー2',
                        isPlayer1 ? player1Points : player2Points,
                        isPlayer1 ? player1OMP : player2OMP,
                        isPlayer1 ? Colors.blue : Colors.red,
                        true, // 自分のプレイヤー情報
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
                        isPlayer1 ? 'プレイヤー2' : 'プレイヤー1',
                        isPlayer1 ? player2Points : player1Points,
                        isPlayer1 ? player2OMP : player1OMP,
                        isPlayer1 ? Colors.red : Colors.blue,
                        false, // 相手のプレイヤー情報
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
                                      crossAxisCount: 5, // 5列に変更
                                      childAspectRatio: 0.7, // カードの縦横比を調整
                                      crossAxisSpacing: 6, // 間隔を少し狭く
                                      mainAxisSpacing: 6,
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

  Widget _buildPlayerInfo(
    String title,
    int points,
    int omp,
    Color color,
    bool isCurrentPlayer,
  ) {
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
        border: isCurrentPlayer ? Border.all(color: color, width: 2) : null,
      ),
      child: Column(
        children: [
          // プレイヤー1/2と自分/相手の両方を表示
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            isCurrentPlayer ? '(あなた)' : '(相手)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
    final cardRank = card['rank'] as String? ?? 'D';
    final cardId = card['id'].toString();

    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          width: 100, // 幅を固定して小さくする
          height: 150, // 高さも調整
          child: CommonCardWidget(
            cardId: cardId,
            name: cardName,
            type: cardType,
            power: cardPower,
            rank: cardRank,
            isSelected: true,
            showSparkles: false, // バトル中はエフェクトを減らす
          ),
        ),
      ],
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
    final cardRank = card['rank'] as String? ?? 'D'; // rankを追加
    final cardId = card['id'].toString();

    return InkWell(
      onTap:
          isWaitingForOpponent || isTurnProcessing || selectedCardId != null
              ? null
              : onSelect,
      child: CommonCardWidget(
        cardId: cardId,
        name: cardName,
        type: cardType,
        power: cardPower,
        rank: cardRank,
        isSelected: isSelected,
        onTap:
            isWaitingForOpponent || isTurnProcessing || selectedCardId != null
                ? null
                : onSelect,
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
