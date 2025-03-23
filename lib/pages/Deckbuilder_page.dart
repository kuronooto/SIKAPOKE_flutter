import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeckBuilderPage extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> ownedCards;
  
  DeckBuilderPage({required this.userId, required this.ownedCards});
  
  @override
  _DeckBuilderPageState createState() => _DeckBuilderPageState();
}

class _DeckBuilderPageState extends State<DeckBuilderPage> {
  List<String> selectedCards = [];

  void toggleCardSelection(String cardId) {
    setState(() {
      if (selectedCards.contains(cardId)) {
        selectedCards.remove(cardId);
      } else if (selectedCards.length < 5) {
        selectedCards.add(cardId);
      }
    });
  }

  void saveDeck() async {
    if (selectedCards.length == 5) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'deck': selectedCards});
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("デッキ編成")),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
              ),
              itemCount: widget.ownedCards.length,
              itemBuilder: (context, index) {
                final card = widget.ownedCards[index];
                final cardId = card['id'];
                final isSelected = selectedCards.contains(cardId);
                return GestureDetector(
                  onTap: () => toggleCardSelection(cardId),
                  child: Card(
                    color: isSelected ? Colors.blueAccent : Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(card['name'], style: TextStyle(fontSize: 16)),
                        if (isSelected) Icon(Icons.check_circle, color: Colors.green)
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: selectedCards.length == 5 ? saveDeck : null,
            child: Text("デッキ保存"),
          )
        ],
      ),
    );
  }
}
