import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CardPage extends StatelessWidget {
  final String userId;

  const CardPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.cyan,
        title: const Text('Card'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('owned_cards')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('所持カードがありません'));
          }

          // Firestoreのデータをリストに変換
          var cards = snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name'] ?? 'Unknown Card'),
              subtitle: Text('所持枚数: ${data['number'] ?? 0}'),
              leading: const Icon(Icons.style, color: Colors.cyan),
            );
          }).toList();

          return ListView(children: cards);
        },
      ),
    );
  }
}