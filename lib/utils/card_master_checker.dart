import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CardMasterChecker extends StatefulWidget {
  const CardMasterChecker({Key? key}) : super(key: key);

  @override
  State<CardMasterChecker> createState() => _CardMasterCheckerState();
}

class _CardMasterCheckerState extends State<CardMasterChecker> {
  bool _checking = false;
  bool? _hasCards;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _checkCardMaster();
  }

  Future<void> _checkCardMaster() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = '';
    });

    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (useEmu) {
      try { functions.useFunctionsEmulator('localhost', 5001); } catch (_) {}
    }

    try {
      // 認証保証
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      } else {
        await FirebaseAuth.instance.currentUser!.getIdToken(true);
      }

      final result = await functions.httpsCallable('getCardsCount').call({});
      final hasAny = result.data['hasAny'] as bool? ?? false;
      
      setState(() {
        _checking = false;
        _hasCards = hasAny;
        _message = hasAny 
            ? 'カードマスタが正常に投入されています' 
            : 'カードマスタが投入されていません。管理者画面から投入してください。';
      });
    } catch (e) {
      setState(() {
        _checking = false;
        _hasCards = false;
        _message = '確認中にエラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('カードマスタ状態:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (_checking)
                  const CircularProgressIndicator(strokeWidth: 2)
                else if (_hasCards == true)
                  const Icon(Icons.check_circle, color: Colors.green)
                else if (_hasCards == false)
                  const Icon(Icons.error, color: Colors.red)
                else
                  const Icon(Icons.help, color: Colors.grey),
              ],
            ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_message),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checking ? null : _checkCardMaster,
              child: const Text('再確認'),
            ),
          ],
        ),
      ),
    );
  }
}
