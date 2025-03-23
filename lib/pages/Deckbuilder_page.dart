import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeckBuilderPage extends StatefulWidget {
  final String userId;
  final String deckId;
  final List<Map<String, dynamic>> ownedCards;

  DeckBuilderPage({required this.userId, required this.deckId, required this.ownedCards});

  @override
  _DeckBuilderPageState createState() => _DeckBuilderPageState();
}

class _DeckBuilderPageState extends State<DeckBuilderPage> {
  List<String> selectedCardIds = [];
  final int maxDeckSize = 5;

  @override
  void initState() {
    super.initState();
    print("受け取った所持カード: ${widget.ownedCards}"); // デバッグログ
    _loadDeck();
  }

  /// Firestoreからデッキ情報を取得
  Future<void> _loadDeck() async {
    final deckRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('decks')
        .doc(widget.deckId);

    final deckSnapshot = await deckRef.get();
    if (deckSnapshot.exists) {
      final List<dynamic> storedCards = deckSnapshot.data()?['cards'] ?? [];
      setState(() {
        selectedCardIds = List<String>.from(storedCards);
      });
    }
  }

  /// カード選択/解除
  void toggleCardSelection(String cardId) {
    setState(() {
      if (selectedCardIds.contains(cardId)) {
        selectedCardIds.remove(cardId);
      } else if (selectedCardIds.length < maxDeckSize) {
        selectedCardIds.add(cardId);
      }
    });
  }

  /// Firestoreにデッキ情報を保存
  Future<void> saveDeck() async {
    if (selectedCardIds.length == maxDeckSize) {
      List<int> selectedCardIdsAsInt = selectedCardIds.map((id) => int.parse(id)).toList(); //int型に変換

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'deck': selectedCardIdsAsInt});
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('デッキが保存されました')),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    print("表示する所持カード: ${widget.ownedCards.length}枚"); // デバッグログ

    return Scaffold(
      appBar: AppBar(title: const Text("デッキ編成")),
      body: Column(
        children: [
          const Text("選択中のカード"),
          Wrap(
            children: selectedCardIds.map((cardId) {
              final card = widget.ownedCards.firstWhere(
                (c) => c['cardId'].toString() == cardId, // `id` → `cardId`
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
                final cardId = card['cardId']?.toString() ?? ''; // `id` → `cardId`
                if (cardId.isEmpty) return const SizedBox.shrink(); // 無効なカードをスキップ

                final isSelected = selectedCardIds.contains(cardId);
                return GestureDetector(
                  onTap: () {
                    print("カードタップ: $cardId");
                    toggleCardSelection(cardId);
                  },
                  child: Card(
                    color: isSelected ? Colors.blueAccent : Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(card['name'], style: const TextStyle(fontSize: 16)),
                        if (isSelected) const Icon(Icons.check_circle, color: Colors.green),
                      ],
                    ),
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
