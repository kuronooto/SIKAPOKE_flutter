import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gacha/gacha_screen.dart';
import '../viewmodels/gacha_view_model.dart';

class PackOpeningPage extends StatelessWidget {
  const PackOpeningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カードパックを開封'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'パックを開封しましょう！',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // GachaScreen に遷移
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => ChangeNotifierProvider(
                          create: (context) => GachaViewModel(),
                          child: const GachaScreen(),
                        ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: const Text(
                'パックを開封する',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
