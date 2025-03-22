import 'package:flutter/material.dart';
import 'pack_opening_page.dart'; // 追加: カードパック開封画面をインポート

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Home Page'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 画面遷移 (Navigatorで `PackOpeningPage` へ移動)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PackOpeningPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'カードパックを引く',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

