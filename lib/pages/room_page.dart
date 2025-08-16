import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/common/card.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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

  // 追加: Functions/同期関連の状態
  late final FirebaseFunctions _functions;
  int? _roomVersion; // Firestoreのversion
  int? _lastEndTurnCalledForTurn; // このターンでendTurnを1回だけ呼ぶためのガード
  int? _lastBattleDialogShownTurn; // バトル結果ダイアログの多重表示防止
  bool _gameOverShown = false; // ゲーム終了ダイアログの多重表示防止
  String? _roomStatus;         // 追加: 直近のroom_status
  String? _lastWinnerId;       // 追加: 直近のwinner_id

  @override
  void initState() {
    super.initState();

    _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    // 追加: main と同じ判定でエミュを使用
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (useEmu) {
      try { _functions.useFunctionsEmulator('localhost', 5001); } catch (_) {}
      try { FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080); } catch (_) {}
      try { FirebaseAuth.instance.useAuthEmulator('localhost', 9099); } catch (_) {} // 追加
    }

    _initializeGameState();
    _fetchPlayerDeck();
    _listenToGameState();
    Future.delayed(const Duration(milliseconds: 500), () { _showPlayerInfoDialog(); });
  }

  @override
  void dispose() {
    // 部屋から退出時に処理（相手がいない場合は部屋を削除）
    _handleRoomExit();
    super.dispose();
  }

  Future<void> _handleRoomExit() async {
    try {
      // Functions 経由で安全に退室
      await _functions.httpsCallable('leaveRoom').call({'roomId': widget.roomId});
      print('leaveRoom 呼び出し完了: ${widget.roomId}');
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
          final ids = List<int>.from(deckData).where((id) => id > 0).toList();
          setState(() {
            playerDeck = ids;
          });

          // 修正: Functions 経由で一括取得
          try {
            final res = await _functions.httpsCallable('fetchCardsByIds').call({'ids': ids});
            final data = (res.data as Map)['cards'] as List<dynamic>? ?? const [];
            setState(() {
              deckCards = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            });
          } catch (e) {
            // 失敗時は空のまま（UIは「デッキが空です」を表示）
            debugPrint('fetchCardsByIds for deck error: $e');
          }
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
        // 追加: version を保持（endTurnのexpectVersionに使用）
        _roomVersion = (data['version'] as int?) ?? 0;

        final gameState = data['game_state'] as Map<String, dynamic>;

        // Firestoreの状態で上書き
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

        // 追加: 最新の room_status / winner_id を保持
        _roomStatus = data['room_status'] as String?;
        _lastWinnerId = data['winner_id'] as String?;

        // 変更: バトル結果ダイアログ表示中は終了ダイアログを即時に出さず、後で出す
        if (_roomStatus == 'finished' && !_gameOverShown && !isTurnProcessing) {
          _gameOverShown = true;
          final winnerId = _lastWinnerId;
          final amIWinner = winnerId != null &&
              ((isPlayer1 && winnerId == widget.player1Id) ||
               (!isPlayer1 && winnerId == widget.player2Id));
          final resultText = amIWinner ? 'あなたの勝ち！' : '相手の勝ち';
          if (mounted) {
            _showGameOverDialog(resultText);
          }
        }

        // 両プレイヤーがカード選択済み -> ターン解決
        if (gameState['player1_card'] != null &&
            gameState['player2_card'] != null) {
          final currentTurn = gameState['turn'] as int? ?? 1;

          // このターンでまだダイアログを出していなければ解決処理開始
          if (_lastBattleDialogShownTurn != currentTurn) {
            setState(() {
              isTurnProcessing = true;
            });
            _resolveTurn(currentTurn, gameState);
          }
        }

        // 次ターン準備（サーバーで解決後、カードはnullに戻る）
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

  // 追加: ターン解決（P1のみendTurn呼び出し、両者ともバトル結果は表示）
  Future<void> _resolveTurn(int currentTurn, Map<String, dynamic> gs) async {
    final p1Id = gs['player1_card'] as int;
    final p2Id = gs['player2_card'] as int;

    // カードデータ取得
    final p1Card = await _fetchCardData(p1Id);
    final p2Card = await _fetchCardData(p2Id);

    // 表示用に反映
    if (mounted) {
      setState(() {
        selectedCardData = isPlayer1 ? p1Card : p2Card;
        opponentCardData = isPlayer1 ? p2Card : p1Card;
      });
    }

    // P1のみサーバーにendTurn（多重防止）
    if (isPlayer1 && _lastEndTurnCalledForTurn != currentTurn) {
      final actionId = DateTime.now().microsecondsSinceEpoch.toString();
      try {
        final result = await _functions.httpsCallable('endTurn').call({
          'roomId': widget.roomId,
          'clientActionId': actionId,
          'expectVersion': _roomVersion,
        });

        final d = Map<String, dynamic>.from(result.data as Map);
        final summary = Map<String, dynamic>.from(d['summary'] as Map? ?? {});
        final p1Final = (summary['p1Final'] as num?)?.toInt() ?? (p1Card['power'] as int? ?? 0);
        final p2Final = (summary['p2Final'] as num?)?.toInt() ?? (p2Card['power'] as int? ?? 0);
        final resultKey = summary['result'] as String?; // 'p1'|'p2'|'draw'
        final resultText = _resultTextFromKey(resultKey);

        // ログ追加（このクライアントで1回のみ）
        setState(() {
          battleLogs.add(
            BattleLogItem(
              turn: currentTurn,
              player1Card: p1Card['name'] as String? ?? 'カード',
              player2Card: p2Card['name'] as String? ?? 'カード',
              player1Power: p1Card['power'] as int? ?? 0,
              player2Power: p2Card['power'] as int? ?? 0,
              player1FinalPower: p1Final,
              player2FinalPower: p2Final,
              player1TypeAdvantage: p1Final > (p1Card['power'] as int? ?? 0),
              player2TypeAdvantage: p2Final > (p2Card['power'] as int? ?? 0),
              result: resultText,
            ),
          );
        });

        await _showBattleResultDialog(
          p1Card,
          p2Card,
          p1Final,
          p2Final,
          resultText,
        );
        // 追加: バトル結果を閉じた直後に、終了状態なら終了ダイアログを出す
        _maybeShowGameOverAfterBattle();
      } catch (e) {
        // 失敗時はローカル計算
        final comp = _computeLocal(p1Card, p2Card);
        setState(() {
          battleLogs.add(
            BattleLogItem(
              turn: currentTurn,
              player1Card: p1Card['name'] as String? ?? 'カード',
              player2Card: p2Card['name'] as String? ?? 'カード',
              player1Power: p1Card['power'] as int? ?? 0,
              player2Power: p2Card['power'] as int? ?? 0,
              player1FinalPower: comp.$1,
              player2FinalPower: comp.$2,
              player1TypeAdvantage: comp.$1 > (p1Card['power'] as int? ?? 0),
              player2TypeAdvantage: comp.$2 > (p2Card['power'] as int? ?? 0),
              result: comp.$3,
            ),
          );
        });
        await _showBattleResultDialog(
          p1Card,
          p2Card,
          comp.$1,
          comp.$2,
          comp.$3,
        );
      } finally {
        _lastEndTurnCalledForTurn = currentTurn;
        _lastBattleDialogShownTurn = currentTurn;
      }
    } else {
      // P2は表示のみ（サーバー更新はP1）
      final comp = _computeLocal(p1Card, p2Card);

      // ログ追加（このクライアントで1回のみ）
      setState(() {
        battleLogs.add(
          BattleLogItem(
            turn: currentTurn,
            player1Card: p1Card['name'] as String? ?? 'カード',
            player2Card: p2Card['name'] as String? ?? 'カード',
            player1Power: p1Card['power'] as int? ?? 0,
            player2Power: p2Card['power'] as int? ?? 0,
            player1FinalPower: comp.$1,
            player2FinalPower: comp.$2,
            player1TypeAdvantage: comp.$1 > (p1Card['power'] as int? ?? 0),
            player2TypeAdvantage: comp.$2 > (p2Card['power'] as int? ?? 0),
            result: comp.$3,
          ),
        );
      });

      await _showBattleResultDialog(
        p1Card,
        p2Card,
        comp.$1,
        comp.$2,
        comp.$3,
      );
      // 追加: バトル結果を閉じた直後に終了ダイアログを出す（必要なら）
      _maybeShowGameOverAfterBattle();

      _lastBattleDialogShownTurn = currentTurn;
    }
  }

  // 追加: バトル結果後の終了ダイアログ表示フォールバック
  void _maybeShowGameOverAfterBattle() {
    if (!mounted) return;
    if (_roomStatus == 'finished' && !_gameOverShown) {
      _gameOverShown = true;
      final winnerId = _lastWinnerId;
      final amIWinner = winnerId != null &&
          ((isPlayer1 && winnerId == widget.player1Id) ||
           (!isPlayer1 && winnerId == widget.player2Id));
      final resultText = amIWinner ? 'あなたの勝ち！' : '相手の勝ち';
      _showGameOverDialog(resultText);
    }
  }

  // 追加: ローカル計算（表示用のみ、サーバーに依存しない）
  (int, int, String) _computeLocal(Map<String, dynamic> p1, Map<String, dynamic> p2) {
    final p1Pow = p1['power'] as int? ?? 0;
    final p2Pow = p2['power'] as int? ?? 0;
    final p1Type = p1['type'] as String? ?? '';
    final p2Type = p2['type'] as String? ?? '';

    int p1Final = p1Pow;
    int p2Final = p2Pow;
    if (typeWeakness[p1Type] == p2Type) p1Final *= 2;
    if (typeWeakness[p2Type] == p1Type) p2Final *= 2;

    String result;
    if (p1Final > p2Final) {
      result = 'プレイヤー1の勝ち';
    } else if (p1Final < p2Final) {
      result = 'プレイヤー2の勝ち';
    } else {
      result = '引き分け';
    }
    return (p1Final, p2Final, result);
  }

  // 追加: 関数キーから人間向けテキストへ
  String _resultTextFromKey(String? key) {
    switch (key) {
      case 'p1':
        return 'プレイヤー1の勝ち';
      case 'p2':
        return 'プレイヤー2の勝ち';
      default:
        return '引き分け';
    }
  }

  // 変更: 旧クライアント更新ロジックを廃止し、表示専用に
  void _processTurn(
    Map<String, dynamic> player1CardData,
    Map<String, dynamic> player2CardData,
  ) {
    final comp = _computeLocal(player1CardData, player2CardData);
    // バトルログを残す（表示用）
    battleLogs.add(
      BattleLogItem(
        turn: turn,
        player1Card: player1CardData['name'] as String? ?? 'カード',
        player2Card: player2CardData['name'] as String? ?? 'カード',
        player1Power: player1CardData['power'] as int? ?? 0,
        player2Power: player2CardData['power'] as int? ?? 0,
        player1FinalPower: comp.$1,
        player2FinalPower: comp.$2,
        player1TypeAdvantage: comp.$1 > (player1CardData['power'] as int? ?? 0),
        player2TypeAdvantage: comp.$2 > (player2CardData['power'] as int? ?? 0),
        result: comp.$3,
      ),
    );

    // 表示のみ（サーバーがスコア・ターンを更新）
    _showBattleResultDialog(
      player1CardData,
      player2CardData,
      comp.$1,
      comp.$2,
      comp.$3,
    );
  }

  // 変更: 旧の「カード選択後に計算＋Firestore更新」を廃止し、選択送信のみ
  void _selectCard(int cardId, Map<String, dynamic> cardData) async {
    if (isWaitingForOpponent || isTurnProcessing || selectedCardId != null) {
      return;
    }

    setState(() {
      selectedCardId = cardId;
      selectedCardData = cardData;
      isWaitingForOpponent = true;
    });

    try {
      // Cloud Functions 経由で選択を送信
      await _functions.httpsCallable('selectCard').call({
        'roomId': widget.roomId,
        'cardId': cardId,
      });
    } catch (e) {
      // 失敗時は元に戻す
      if (mounted) {
        setState(() {
          selectedCardId = null;
          selectedCardData = null;
          isWaitingForOpponent = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('カード送信に失敗しました')),
        );
      }
    }
  }

  // 変更: 旧の「カード選択時に即座に処理」→ 表示用のデータ反映のみ
  void _handleCardSelection(int player1CardId, int player2CardId) async {
    final player1CardData = await _fetchCardData(player1CardId);
    final player2CardData = await _fetchCardData(player2CardId);

    if (mounted) {
      setState(() {
        selectedCardData = isPlayer1 ? player1CardData : player2CardData;
        opponentCardData = isPlayer1 ? player2CardData : player1CardData;
      });
    }
    // 解決は _resolveTurn 側で実施
  }

  Future<Map<String, dynamic>> _fetchCardData(int cardId) async {
    try {
      // 修正: 単体でも Functions の一括取得APIを使う
      final res = await _functions.httpsCallable('fetchCardsByIds').call({'ids': [cardId]});
      final list = (res.data as Map)['cards'] as List<dynamic>? ?? const [];
      if (list.isNotEmpty) {
        return Map<String, dynamic>.from(list.first as Map);
      }
    } catch (e) {
      debugPrint('fetchCardsByIds(single) error: $e');
    }

    // デフォルト（取得失敗時）
    return {
      'id': cardId,
      'name': 'カード #$cardId',
      'type': 'unknown',
      'power': 0,
      'rank': 'E',
    };
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

  // 追加: ゲーム終了ダイアログ（Roomのroom_status=finished時に1回だけ表示）
  void _showGameOverDialog(String result) {
    if (!mounted) return;

    final myScore = isPlayer1 ? player1Points : player2Points;
    final oppScore = isPlayer1 ? player2Points : player1Points;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isWin = result.contains('勝ち');
        return AlertDialog(
          title: const Text('ゲーム終了'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 64,
                color: isWin ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                result,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'スコア: $myScore - $oppScore',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();  // ダイアログを閉じる
                Navigator.of(context).pop();  // ルームページを閉じる
              },
              child: const Text('終了する'),
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

// バトルログ用のクラス（トップレベルに1つだけ定義）
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