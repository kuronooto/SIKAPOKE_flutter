import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// 効果音の再生を担当するサービスクラス
class SoundService {
  /// 効果音プレーヤー
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 音響効果の有効/無効フラグ
  bool _soundEnabled = true;

  /// サウンドが有効かどうかを取得
  bool get isSoundEnabled => _soundEnabled;

  /// サウンドの有効/無効を切り替える
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
  }

  /// リソースを解放する
  void dispose() {
    _audioPlayer.dispose();
  }

  /// 効果音を再生するヘルパーメソッド
  Future<void> playSound(String soundPath) async {
    if (!_soundEnabled) return;

    try {
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      debugPrint('効果音の再生に失敗しました: $e');
    }
  }

  /// 選択時の効果音
  Future<void> playSelectSound() async {
    await playSound('sounds/select.mp3');
  }

  /// パック開封時の効果音
  Future<void> playPackOpenSound() async {
    await playSound('sounds/open.mp3');
  }

  /// カード出現時の効果音（レア度に応じて異なる効果音）
  Future<void> playCardRevealSound(int rarityLevel) async {
    if (rarityLevel >= 4) {
      await playSound('sounds/result_legendary.mp3');
    } else if (rarityLevel >= 3) {
      await playSound('assets/sounds/result_epic.mp3');
    } else {
      await playSound('sounds/result.mp3');
    }
  }

  /// きらきらエフェクト音（高レア時）
  Future<void> playSparkleSound() async {
    await playSound('sounds/sparkle.mp3');
  }
}
