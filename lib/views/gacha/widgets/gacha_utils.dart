import 'package:flutter/material.dart';

/// ガチャ関連のユーティリティ関数とヘルパーを提供するクラス
class GachaUtils {
  /// レア度に応じた背景色を取得
  static List<Color> getBackgroundColors(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return [Colors.deepPurple.shade100, Colors.deepPurple.shade200];
      case 2:
        return [Colors.deepPurple.shade200, Colors.deepPurple.shade300];
      case 3:
        return [Colors.deepPurple.shade300, Colors.deepPurple.shade400];
      case 4:
        return [Colors.deepPurple.shade400, Colors.deepPurple.shade500];
      default:
        return [Colors.deepPurple.shade100, Colors.deepPurple.shade200];
    }
  }

  /// レア度に応じた光るエフェクトの色を取得
  static Color getGlowColor(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Colors.blue.shade400;
      case 2:
        return Colors.purple.shade400;
      case 3:
        return Colors.pink.shade300;
      case 4:
        return Colors.yellow.shade300;
      default:
        return Colors.blue.shade400;
    }
  }

  /// レア度に応じたカードのグラデーションを取得
  static List<Color> getCardGradient(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return [Colors.deepPurple.shade300, Colors.deepPurple.shade200];
      case 2:
        return [Colors.deepPurple.shade400, Colors.deepPurple.shade300];
      case 3:
        return [Colors.deepPurple.shade500, Colors.deepPurple.shade400];
      case 4:
        return [Colors.deepPurple.shade700, Colors.deepPurple.shade500];
      case 5:
        return [Colors.deepPurple.shade900, Colors.purple.shade300];
      default:
        return [Colors.deepPurple.shade300, Colors.deepPurple.shade200];
    }
  }

  /// レア度に応じたテキストを取得
  static String getRarityText(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return 'ノーマル';
      case 2:
        return 'レア';
      case 3:
        return 'スーパーレア';
      case 4:
        return 'ウルトラレア';
      case 5:
        return 'レジェンド';
      default:
        return 'ノーマル';
    }
  }

  /// レア度の星表示を取得
  static String getRarityStars(int rarityLevel) {
    return '★' * rarityLevel;
  }

  /// レア度の星の色を取得
  static Color getRarityStarColor(int rarityLevel) {
    switch (rarityLevel) {
      case 1:
        return Colors.white;
      case 2:
        return Colors.yellow.shade200;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.amber;
      case 5:
        return Colors.orange;
      default:
        return Colors.white;
    }
  }

  /// 値の範囲をマッピングするユーティリティ関数
  static double map(
    double value,
    double fromLow,
    double fromHigh,
    double toLow,
    double toHigh,
  ) {
    return toLow + (value - fromLow) * (toHigh - toLow) / (fromHigh - fromLow);
  }
}
