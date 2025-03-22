import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CardPage extends StatelessWidget {
  final String userId;

  const CardPage({super.key, required this.userId});

  /// ユーザーの所持カードを取得し、それに対応するカード情報を結合
  Future<List<Map<String, dynamic>>> getOwnedCardDetails() async {
    CollectionReference ownedCardsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('owned_cards');

    CollectionReference cardsRef = FirebaseFirestore.instance.collection('cards');

    try {
      QuerySnapshot ownedSnapshot = await ownedCardsRef.get();
      List<Map<String, dynamic>> ownedCards = ownedSnapshot.docs.map((doc) {
        return {
          'cardId': doc['id'],
          'number': doc['number'],
        };
      }).toList();

      List<Map<String, dynamic>> cardDetails = [];

      for (var ownedCard in ownedCards) {
        String cardId = ownedCard['cardId'].toString(); // IDを文字列に変換

        // 一致するカード情報を取得
        QuerySnapshot cardSnapshot = await cardsRef.where('id', isEqualTo: int.parse(cardId)).get();

        if (cardSnapshot.docs.isNotEmpty) {
          var cardData = cardSnapshot.docs.first.data() as Map<String, dynamic>;
          cardDetails.add({
            'cardId': cardData['id'],
            'name': cardData['name'],
            'power': cardData['power'],
            'rank': cardData['rank'],
            'type': cardData['type'],
            'number': ownedCard['number'],
          });
        }
      }

      return cardDetails;
    } catch (e) {
      print("エラー: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("所持カード一覧")),
      body: FutureBuilder(
        future: getOwnedCardDetails(),
        builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("エラーが発生しました"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("カードを所持していません"));
          }

          List<Map<String, dynamic>> cards = snapshot.data!;

          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) {
              var card = cards[index];
              return Card(
                child: ListTile(
                  title: Text("${card['name']} (ID: ${card['cardId']})"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("パワー: ${card['power']}"),
                      Text("ランク: ${card['rank']}"),
                      Text("タイプ: ${card['type']}"),
                      Text("所持枚数: ${card['number']}枚"),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
