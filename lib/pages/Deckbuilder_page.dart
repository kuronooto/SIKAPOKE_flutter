import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/common/card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class DeckBuilderPage extends StatefulWidget {
  final String userId;
  final String deckId;
  final List<Map<String, dynamic>> ownedCards;

  DeckBuilderPage({
    required this.userId,
    required this.deckId,
    required this.ownedCards,
  });

  @override
  _DeckBuilderPageState createState() => _DeckBuilderPageState();
}

class _DeckBuilderPageState extends State<DeckBuilderPage> {
  List<String> selectedCardIds = [];
  final int maxDeckSize = 5;

  // 所持カードのIDセット（cardId / id 両対応）
  late final Set<String> _ownedIdSet;

  String? _effectiveUid; // 実際に読み書きに使う uid（currentUser を優先）

  @override
  void initState() {
    super.initState();
    print("受け取った所持カード: ${widget.ownedCards}"); // デバッグログ
    _ownedIdSet = widget.ownedCards
        .map((c) => ((c['cardId'] ?? c['id'])?.toString() ?? ''))
        .where((s) => s.isNotEmpty)
        .toSet();

    // 追加: 認証を保証し、currentUser の uid を採用
    _initAuthAndLoad();
  }

  // 追加: 認証を保証してから uid を確定 → デッキ読込
  Future<void> _initAuthAndLoad() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      } else {
        // 念のためトークン更新
        await auth.currentUser!.getIdToken(true);
      }
      final cur = auth.currentUser?.uid;
      setState(() {
        _effectiveUid = cur ?? widget.userId;
      });

      if (cur != null && widget.userId != cur && mounted) {
        debugPrint('DeckBuilderPage: widget.userId(${widget.userId}) != currentUser.uid($cur)。currentUser を使用します。');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログイン中のユーザーに対してデッキを保存します')),
        );
      }

      await _loadDeck();
    } catch (e) {
      debugPrint('Auth init failed: $e');
    }
  }

  /// Firestoreからデッキ情報を取得（users/{uid}.deck に統一）
  Future<void> _loadDeck() async {
    final uid = _effectiveUid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final userSnapshot = await userRef.get();
    if (userSnapshot.exists) {
      final List<dynamic>? deck = userSnapshot.data()?['deck'] as List<dynamic>?;
      if (deck != null) {
        // 0 を除外、数値化、安全に文字列化 → 所持カードに存在するIDのみ → 重複排除 → 最大枚数に制限
        final filtered = deck
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((id) => id > 0)
            .map((id) => id.toString())
            .where((sid) => _ownedIdSet.contains(sid))
            .toSet()
            .take(maxDeckSize)
            .toList();
        setState(() {
          selectedCardIds = filtered;
        });
      }
    }
  }

  /// カード選択/解除（上限超過時はスナックバーで通知）
  void toggleCardSelection(String cardId) {
    if (selectedCardIds.contains(cardId)) {
      setState(() {
        selectedCardIds.remove(cardId);
      });
      return;
    }
    if (selectedCardIds.length >= maxDeckSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('デッキは最大 $maxDeckSize 枚までです')),
      );
      return;
    }
    setState(() {
      selectedCardIds.add(cardId);
    });
  }

  /// Firestoreにデッキ情報を保存（Functions経由に統一）
  Future<void> saveDeck() async {
    if (selectedCardIds.length != maxDeckSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('デッキは $maxDeckSize 枚選択してください')),
      );
      return;
    }

    // 認証を確保
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    await auth.currentUser!.getIdToken(true); // トークン更新

    // カードIDリストを作成（無効な値を除外）- int型に厳密に変換
    final List<int> deckIds = selectedCardIds
        .map((id) => int.tryParse(id) ?? 0)
        .where((id) => id > 0)
        .toList();

    if (deckIds.length < maxDeckSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('有効なカードが $maxDeckSize 枚必要です')),
      );
      return;
    }

    try {
      // Functions経由での保存に統一
      await _saveUsingFunctions(deckIds);
      
      // 保存成功
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('デッキが保存されました')),
      );
      Navigator.pop(context);
    } catch (e) {
      // エラーログ
      debugPrint('デッキ保存エラー: $e');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗: ${e.toString()}')),
      );
    }
  }
  
  // Functions経由のデッキ保存処理（すべての保存はこちらを経由）
  Future<void> _saveUsingFunctions(List<int> deckIds) async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    
    // エミュレータ設定（必要な場合）
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (useEmu) {
      try { functions.useFunctionsEmulator('localhost', 5001); } catch (_) {}
    }
    
    debugPrint('Functions経由でデッキ保存開始: $deckIds');
    final result = await functions.httpsCallable('saveDeck').call({'deck': deckIds});
    debugPrint('Functions経由でデッキ保存成功: ${result.data}');
  }

  @override
  Widget build(BuildContext context) {
    print("表示する所持カード: ${widget.ownedCards.length}枚"); // デバッグログ

    return Scaffold(
      appBar: AppBar(title: const Text("デッキ編成")),
      body: Column(
        children: [
          Text("選択中のカード：${selectedCardIds.length}枚"),
          // 追加: 新規作成用のリセット / 再読込
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() { selectedCardIds = []; });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('リセット'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _loadDeck,
                icon: const Icon(Icons.download),
                label: const Text('現在のデッキを再読込'),
              ),
            ],
          ),
          Wrap(
            children: selectedCardIds.map((cardId) {
              final card = widget.ownedCards.firstWhere(
                (c) => ((c['cardId'] ?? c['id'])?.toString() ?? '') == cardId,
                orElse: () => {},
              );
              return card.isNotEmpty
                  ? Chip(
                      label: Text(card['name']),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () => toggleCardSelection(cardId),
                    )
                  : const SizedBox.shrink();
            }).toList(),
          ),
          const Divider(),
          const Text("所持カード"),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
              ),
              itemCount: widget.ownedCards.length, // 明示的に設定
              itemBuilder: (context, index) {
                final card = widget.ownedCards[index];
                final cardId = ((card['cardId'] ?? card['id'])?.toString() ?? ''); // cardId / id 両対応
                if (cardId.isEmpty) return const SizedBox.shrink();

                final isSelected = selectedCardIds.contains(cardId);

                // InkWell で確実にタップを検出（CommonCardWidget 内の onTap は無効化）
                return InkWell(
                  onTap: () => toggleCardSelection(cardId),
                  child: CommonCardWidget(
                    cardId: cardId,
                    name: card['name'] ?? '',
                    type: card['type'] ?? '',
                    power: card['power'] ?? 0,
                    rank: card['rank'] ?? 'D',
                    isSelected: isSelected,
                    onTap: null, // 二重トリガー防止
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: selectedCardIds.length == maxDeckSize ? saveDeck : null,
            child: const Text("デッキ保存"),
          ),
        ],
      ),
    );
  }
}