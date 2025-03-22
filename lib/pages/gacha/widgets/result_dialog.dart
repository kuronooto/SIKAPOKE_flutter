import 'package:flutter/material.dart';
import '../../../models/pack_model.dart';

class ResultDialog extends StatelessWidget {
  final CardResult result;
  final VoidCallback onClose;

  const ResultDialog({Key? key, required this.result, required this.onClose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'ゲット！',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 獲得したカードの表示
          Container(
            width: 200,
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getGradientColors(result.rarityLevel),
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                result.imagePath,
                height: 180,
                errorBuilder: (context, error, stackTrace) {
                  // 画像が見つからない場合はアイコンで代用
                  return const Icon(
                    Icons.catching_pokemon,
                    size: 100,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            result.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'レア度: ${result.rarityStars}',
            style: TextStyle(
              fontSize: 16,
              color: _getRarityColor(result.rarityLevel),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text(
            'OK',
            style: TextStyle(fontSize: 18, color: Colors.deepPurple),
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return [Colors.blue.shade300, Colors.lightBlue.shade100];
      case 2:
        return [Colors.purple.shade300, Colors.purple.shade100];
      case 3:
        return [Colors.orange.shade300, Colors.yellow.shade200];
      case 4:
        return [Colors.pink.shade300, Colors.purple.shade200];
      case 5:
        return [Colors.red.shade400, Colors.amber.shade300];
      default:
        return [Colors.blue.shade300, Colors.lightBlue.shade100];
    }
  }

  Color _getRarityColor(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Colors.blue.shade700;
      case 2:
        return Colors.purple.shade700;
      case 3:
        return Colors.orange.shade700;
      case 4:
        return Colors.pink.shade700;
      case 5:
        return Colors.red.shade700;
      default:
        return Colors.blue.shade700;
    }
  }
}
