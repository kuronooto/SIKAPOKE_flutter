import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 追加: マスタ投入ページ
import '../utils/upload_cards.dart';

class FunctionsTestPage extends StatefulWidget {
  const FunctionsTestPage({Key? key}) : super(key: key);

  @override
  State<FunctionsTestPage> createState() => _FunctionsTestPageState();
}

class _FunctionsTestPageState extends State<FunctionsTestPage> {
  final TextEditingController _textController = TextEditingController();
  String _resultMessage = '';
  bool _isLoading = false;

  // 部屋ID/カードID入力
  final _roomIdController = TextEditingController();
  final _cardIdController = TextEditingController();
// デフォルトではなく region一致のインスタンスを使う
FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  void initState() {
    super.initState();
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (useEmu) {
      try { _functions.useFunctionsEmulator('localhost', 5001); } catch (_) {}
      try { FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080); } catch (_) {}
      try { FirebaseAuth.instance.useAuthEmulator('localhost', 9099); } catch (_) {} // 追加
    }
  }

  Future<bool> _hasAnyCards() async {
    try {
      final res = await _functions.httpsCallable('getCardsCount').call(<String, dynamic>{});
      final data = res.data as Map;
      return (data['hasAny'] as bool?) ?? false;
    } on FirebaseFunctionsException catch (e) {
      // 取得エラー時に詳細を UI に出すためラップ
      throw Exception('code=${e.code} message=${e.message} details=${e.details}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追加: 接続先の明示（Webでも --dart-define で制御）
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);

    return Scaffold(
      appBar: AppBar(title: const Text('Functions テスト')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 追加: 現在の接続先を表示
            Text('Backend: ${useEmu ? "Emulator" : "Production"}'),
            const SizedBox(height: 8),

            Text('認証: ${FirebaseAuth.instance.currentUser != null ? 'ログイン中' : '未ログイン'}'),
            const SizedBox(height: 12),
            // ...existing code...
            const SizedBox(height: 16),

            const Divider(),
            const Text('カードマスタ'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                // DataUploadPage を開いて「Upload Data」を押下して投入
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DataUploadPage()),
                );
                setState(() {}); // 戻ったら表示更新
              },
              child: const Text('カードマスタ投入ページを開く'),
            ),

            const SizedBox(height: 16),

            // 修正: Callable で cards 状態を確認（権限制限の影響を受けない）
            FutureBuilder<bool>(
              future: _hasAnyCards(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Text('cards(${useEmu ? "emu" : "prod"}): 確認中...');
                }
                if (snap.hasError) return Text('cards(${useEmu ? "emu" : "prod"}): 取得エラー ${snap.error}');
                final hasAny = snap.data ?? false;
                return Text('cards(${useEmu ? "emu" : "prod"}): ${hasAny ? "投入済み" : "未投入"}');
              },
            ),

            const SizedBox(height: 16),

            // 対戦テスト（残す）
            const Divider(),
            const Text('対戦テスト'),
            const SizedBox(height: 8),
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(labelText: 'roomId（空で新規作成）'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _callWithDetail(
                      () => _functions.httpsCallable('createOrJoinRoom').call({'roomId': ''}),
                      onSuccess: (d) {
                        final id = d['roomId']?.toString() ?? '';
                        if (id.isNotEmpty) _roomIdController.text = id;
                        return '部屋作成: $id as ${d['joinedAs']}';
                      },
                    ),
                    child: const Text('部屋を作成'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _callWithDetail(
                      () => _functions.httpsCallable('createOrJoinRoom')
                          .call({'roomId': _roomIdController.text.trim()}),
                      onSuccess: (d) => '参加: ${d['roomId']} as ${d['joinedAs']}',
                    ),
                    child: const Text('部屋に参加'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cardIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'cardId（数値）'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      // ...existing code for selectCard...
                      final roomId = _roomIdController.text.trim();
                      final cardText = _cardIdController.text.trim();
                      if (roomId.isEmpty || cardText.isEmpty) {
                        setState(() => _resultMessage = 'roomId と cardId を入力');
                        return;
                      }
                      final cardId = int.tryParse(cardText);
                      if (cardId == null) {
                        setState(() => _resultMessage = 'cardId は数値で入力');
                        return;
                      }
                      await _callWithDetail(
                        () => _functions.httpsCallable('selectCard').call({'roomId': roomId, 'cardId': cardId}),
                        onSuccess: (_) => 'カード選択: $cardId',
                      );
                    },
                    child: const Text('カード選択'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      final roomId = _roomIdController.text.trim();
                      if (roomId.isEmpty) {
                        setState(() => _resultMessage = 'roomId を入力');
                        return;
                      }
                      // 最新 version を取得して expectVersion に渡す
                      final snap = await FirebaseFirestore.instance.collection('rooms').doc(roomId).get();
                      final v = (snap.data()?['version'] as int?) ?? 0;

                      await _callWithDetail(
                        () => _functions.httpsCallable('endTurn').call({
                          'roomId': roomId,
                          'clientActionId': DateTime.now().microsecondsSinceEpoch.toString(),
                          'expectVersion': v,
                        }),
                        onSuccess: (d) => 'endTurn ok: v=${d['version']} result=${d['summary']?['result']}',
                      );
                    },
                    child: const Text('endTurn'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('room 状態'),
            const SizedBox(height: 8),
            Expanded(
              child: _roomIdController.text.trim().isEmpty
                  ? const Text('roomId を入力/作成してください')
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('rooms')
                          .doc(_roomIdController.text.trim())
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        if (!snap.data!.exists) return const Text('room が見つかりません');
                        final d = snap.data!.data()!;
                        final gs = (d['game_state'] ?? {}) as Map<String, dynamic>;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'turn: ${gs['turn']}\n'
                              'p1: pts=${gs['player1_point']} omp=${gs['player1_over_mount']} card=${gs['player1_card']}\n'
                              'p2: pts=${gs['player2_point']} omp=${gs['player2_over_mount']} card=${gs['player2_card']}',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Future<void> _callWithDetail(
    Future<HttpsCallableResult<dynamic>> Function() call, {
    required String Function(dynamic data) onSuccess,
  }) async {
    setState(() { _isLoading = true; _resultMessage = ''; });
    try {
      // 認証が必要な関数のために匿名ログインでOK（既にログイン中ならスキップ）
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      } else {
        await FirebaseAuth.instance.currentUser!.getIdToken(true); // トークン更新
      }

      final result = await call();
      setState(() { _resultMessage = onSuccess(result.data); });
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FunctionsException code=${e.code} message=${e.message} details=${e.details}');
      }
      setState(() {
        _resultMessage = 'code=${e.code}\nmessage=${e.message}\ndetails=${e.details}';
      });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Other error: $e');
      }
      setState(() { _resultMessage = 'その他のエラー: $e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }
}