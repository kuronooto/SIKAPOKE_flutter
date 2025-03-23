import 'package:flutter/material.dart';

class CardWidget extends StatelessWidget {
  final int cardId;
  final Map<String, dynamic>? cardData;
  final bool isSelected;
  final bool isRevealed;
  final VoidCallback? onTap;
  final bool isOpponent;

  const CardWidget({
    Key? key,
    required this.cardId,
    this.cardData,
    this.isSelected = false,
    this.isRevealed = false,
    this.onTap,
    this.isOpponent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color cardColor = _getCardColor(cardData?['type'] ?? '');
    final int power = cardData?['power'] ?? 0;
    final String cardName = cardData?['name'] ?? 'カード $cardId';
    final String cardType = cardData?['type'] ?? '不明';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 150,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child:
            isOpponent && !isRevealed
                ? _buildBackface()
                : _buildCardContent(cardColor, power, cardName, cardType),
      ),
    );
  }

  Widget _buildBackface() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: Colors.grey.shade800,
      ),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    Color cardColor,
    int power,
    String cardName,
    String cardType,
  ) {
    return Column(
      children: [
        // カードヘッダー（タイプ）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Text(
            cardType,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // カードイメージ
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            child:
                cardData?['image'] != null
                    ? Image.network(cardData!['image'], fit: BoxFit.contain)
                    : Icon(
                      _getIconForType(cardType),
                      size: 40,
                      color: cardColor,
                    ),
          ),
        ),

        // カード名
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            cardName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),

        // パワー表示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: cardColor.withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(7),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flash_on, size: 16, color: Colors.amber),
              Text(
                power.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getCardColor(String type) {
    switch (type) {
      case 'IT':
        return Colors.blue;
      case '語学':
        return Colors.green;
      case 'ビジネス':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'IT':
        return Icons.computer;
      case '語学':
        return Icons.language;
      case 'ビジネス':
        return Icons.business;
      default:
        return Icons.help_outline;
    }
  }
}
