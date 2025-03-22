import 'dart:math';
import 'package:flutter/material.dart';
import '../models/pack_model.dart';
import '../services/card_gacha_service.dart';

class GachaViewModel extends ChangeNotifier {
  final CardGachaService _cardGachaService = CardGachaService();

  final List<PackModel> packs = [
    PackModel(
      id: 'normal',
      name: 'ノーマルパック',
      color: Colors.deepPurple.shade300,
      imagePath: 'assets/images/packs/normal_pack.png',
      rarityLevel: 1,
    ),
    PackModel(
      id: 'rare',
      name: 'レアパック',
      color: Colors.deepPurple.shade400,
      imagePath: 'assets/images/packs/rare_pack.png',
      rarityLevel: 2,
    ),
    PackModel(
      id: 'super_rare',
      name: '最強の遺伝子',
      color: Colors.deepPurple.shade500,
      imagePath: 'assets/images/packs/super_rare_pack.png',
      rarityLevel: 3,
    ),
    PackModel(
      id: 'legend',
      name: 'レジェンドパック',
      color: Colors.deepPurple.shade600,
      imagePath: 'assets/images/packs/legend_pack.png',
      rarityLevel: 4,
    ),
    // 追加パック
    PackModel(
      id: 'limited',
      name: 'リミテッドパック',
      color: Colors.deepPurple.shade700,
      imagePath: 'assets/images/packs/limited_pack.png',
      rarityLevel: 4,
    ),
    PackModel(
      id: 'anniversary',
      name: '記念パック',
      color: Colors.purple.shade400,
      imagePath: 'assets/images/packs/anniversary_pack.png',
      rarityLevel: 3,
    ),
    PackModel(
      id: 'special',
      name: 'スペシャルパック',
      color: Colors.indigo.shade400,
      imagePath: 'assets/images/packs/special_pack.png',
      rarityLevel: 3,
    ),
    PackModel(
      id: 'premium',
      name: 'プレミアムパック',
      color: Colors.deepPurple.shade800,
      imagePath: 'assets/images/packs/premium_pack.png',
      rarityLevel: 4,
    ),
  ];

  int _selectedPackIndex = 0;
  bool _isSelecting = false;
  bool _isOpening = false;
  bool _isLoading = false; // カード取得中のローディング状態
  CardResult? _result;
  String? _errorMessage; // エラーメッセージ

  int get selectedPackIndex => _selectedPackIndex;
  bool get isSelecting => _isSelecting;
  bool get isOpening => _isOpening;
  bool get isLoading => _isLoading;
  CardResult? get result => _result;
  String? get errorMessage => _errorMessage;
  bool get hasSelectedPack => _selectedPackIndex != -1;

  void startPackSelection() {
    if (_isSelecting || _isOpening) return;

    _isSelecting = true;
    // ランダムなパックを選択
    _selectedPackIndex = Random().nextInt(packs.length);
    notifyListeners();
  }

  void selectPack(int index) {
    if (_isSelecting || _isOpening) return;

    _selectedPackIndex = index;
    notifyListeners();
  }

  void openSelectedPack() async {
    if (_isOpening || _selectedPackIndex == -1) return;

    _isOpening = true;
    _isLoading = true;
    _result = null; // 前回の結果をクリア
    _errorMessage = null; // エラーメッセージをクリア
    notifyListeners();

    try {
      // 選択したパックのレアリティに基づいてカードを取得
      final selectedPack = packs[_selectedPackIndex];
      final cardResult = await _cardGachaService.getRandomCard(
        selectedPack.rarityLevel,
      );

      _result = cardResult;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'カードの取得に失敗しました: ${e.toString()}';
      _isLoading = false;
      notifyListeners();

      // エラー後、3秒後に状態をリセット
      Future.delayed(const Duration(seconds: 3), () {
        resetSelection();
      });
    }
  }

  void resetSelection() {
    _isSelecting = false;
    _isOpening = false;
    _isLoading = false;
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }

  // 完全にリセットする
  void completeReset() {
    _isSelecting = false;
    _isOpening = false;
    _isLoading = false;
    _result = null;
    _errorMessage = null;
    _selectedPackIndex = 0; // デフォルトのパックを選択
    notifyListeners();
  }

  void completeSelection() {
    _isSelecting = false;
    notifyListeners();
  }

  void completeOpening() {
    // _isOpening = false; // この行はコメントアウト：結果表示後もisOpening状態を保持
    notifyListeners();
  }
}
