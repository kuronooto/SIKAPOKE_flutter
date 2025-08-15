import 'dart:math';
import 'package:flutter/material.dart';
import '../models/pack_model.dart';
import '../services/card_gacha_service.dart';

class GachaViewModel extends ChangeNotifier {
  final CardGachaService _cardGachaService = CardGachaService();

  // コンストラクタ - 初期化時にデフォルトのパックを生成
  GachaViewModel() {
    // 初期状態では最強の資格パックを8枚生成
    _selectedPackTypeIndex = 0; // デフォルトは「最強の資格」(インデックス0)
    _generatePacksFromType(_selectedPackTypeIndex);

    // print('GachaViewModel初期化: ${_packs.length}枚のパックを生成しました');
  }

  // パックタイプのインデックス（選択画面から選ばれたパックタイプ）
  int _selectedPackTypeIndex = 0;
  int get selectedPackTypeIndex => _selectedPackTypeIndex;

  // パックの定義（選択画面で表示するパックの種類）
  final List<PackModel> packTypes = [
    PackModel(
      id: 'normal',
      name: '最強の資格',
      color: Colors.deepPurple.shade300,
      imagePath: 'assets/images/packs/normal_pack.png',
      rarityLevel: 1,
    ),
    PackModel(
      id: 'rare',
      name: '資格のある島',
      color: Colors.blue.shade400,
      imagePath: 'assets/images/packs/rare_pack.png',
      rarityLevel: 2,
    ),
    PackModel(
      id: 'super_rare',
      name: '時空の資格',
      color: Colors.teal.shade500,
      imagePath: 'assets/images/packs/super_rare_pack.png',
      rarityLevel: 3,
    ),
    PackModel(
      id: 'legend',
      name: '超克の資格',
      color: const Color.fromARGB(255, 252, 199, 39),
      imagePath: 'assets/images/packs/legend_pack.png',
      rarityLevel: 4,
    ),
    // ...existing code...
    PackModel(
      id: 'new_only',
      name: '存在しない資格',
      color: const Color.fromARGB(255, 242, 244, 242),
      imagePath: 'assets/images/packs/legend_pack.png', // 新しい画像パス
      rarityLevel: 5,
    ),
// ...existing code...
  ];

  // 選択されたパックの複製を8枚生成するリスト
  List<PackModel> _packs = [];

  // ガチャ画面で表示するパックのゲッター
  List<PackModel> get packs => _packs;

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

  // 選択されたパックタイプから8枚のパックを生成する
  void _generatePacksFromType(int typeIndex) {
    if (typeIndex < 0 || typeIndex >= packTypes.length) {
      typeIndex = 0; // インデックスが範囲外の場合はデフォルトに
    }

    PackModel packType = packTypes[typeIndex];

    // 8枚の同じデザイン・同じ色のパックを生成
    _packs = List.generate(
      8,
      (i) => PackModel(
        id: '${packType.id}_$i',
        name: packType.name,
        color: packType.color,
        imagePath: packType.imagePath,
        rarityLevel: packType.rarityLevel,
      ),
    );

    // print('パック生成: 8枚の${packType.name}パックを生成しました (色: ${packType.color})');
  }

  void startPackSelection() {
    if (_isSelecting || _isOpening) return;

    _isSelecting = true;
    // ランダムなパックインデックスを選択（同じタイプのパックが複数あるので）
    if (_packs.isNotEmpty) {
      _selectedPackIndex = Random().nextInt(_packs.length);
    } else {
      _selectedPackIndex = 0;
    }
    notifyListeners();
  }

  // パック選択画面でパックタイプを選択した時に呼ばれるメソッド
  void selectPackType(int typeIndex) {
    if (typeIndex < 0 || typeIndex >= packTypes.length) return;

    // print('パックタイプ選択: タイプ${typeIndex}を選択');
    _selectedPackTypeIndex = typeIndex;

    // パックを生成
    _generatePacksFromType(typeIndex);

    _selectedPackIndex = 0; // 初期選択インデックスをリセット

    // 状態変更を通知
    notifyListeners();
  }

  // ガチャ画面内でパックを選択した時に呼ばれるメソッド
  void selectPack(int index) {
    if (_isSelecting || _isOpening) return;
    if (index < 0 || index >= _packs.length) return;

    _selectedPackIndex = index;
    notifyListeners();
  }

  void openSelectedPack() async {
    if (_isOpening || _selectedPackIndex == -1 || _packs.isEmpty) return;

    _isOpening = true;
    _isLoading = true;
    _result = null; // 前回の結果をクリア
    _errorMessage = null; // エラーメッセージをクリア
    notifyListeners();

    try {
      // 現在選択されているパックを取得
      final selectedPack = _packs[_selectedPackIndex];
      // print(
      //   'パック開封: ${selectedPack.name}パックを開封します (rarityLevel: ${selectedPack.rarityLevel}, 色: ${selectedPack.color})',
      // );

      // 選択したパックのレアリティに基づいてカードを取得
      final cardResult = await _cardGachaService.getRandomCard(
        selectedPack.rarityLevel,
      );

      _result = cardResult;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // print('パック開封エラー: $e');
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

    // パックが存在しない場合は、現在選択されているパックタイプのパックを8枚生成
    if (_packs.isEmpty) {
      _generatePacksFromType(_selectedPackTypeIndex);
    }

    _selectedPackIndex = 0; // 最初のパックを選択

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
