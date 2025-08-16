# チーム「g」
## 概要
re-build福岡2025
プロダクト名：「SIKAPOKE」

Flutter × Firebase（Auth/Firestore/Functions）で実装したカード対戦アプリ。  
- ページ構成: Home / Card / Battle（デバッグ時のみ Functions テストページ表示）
- バックエンド: Cloud Functions for Firebase（us-central1）
- データ: Firestore（cards / users / rooms 他）

### プロダクト概要
- カード（id, name, type, power, rank）で対戦
- カード相性: IT > 語学 > ビジネス > IT（有利側はパワー2倍）
- 勝利条件: 先に3ポイント獲得
- 失格条件: OMP（Over Mount Point）が閾値を超えると敗北（仕様: OMPが150を超えると敗北。Functions・UI共に150を閾値とする）
- マッチング:
  - createOrJoinRoom（空き待機ルームへ参加 or 新規作成）
  - selectCard（選択のみ。解決はサーバー）
  - endTurn（P1のみが呼び出し。サーバーで勝敗・OMP・version 更新）
  - leaveRoom（退室/待機へ戻す/削除）

主な Cloud Functions（src/index.ts）
- createOrJoinRoom, selectCard, endTurn, leaveRoom
- fetchCardsByIds, adminUpsertCards, getCardsCount
- drawGacha, addCardToUserCollection, ensureUserInitialized, saveDeck, testWriteFirestore

画面メモ
- Card: 所持カード一覧（owned_cards と cards を突合）。DeckBuilder へ遷移可能
- Battle: デッキからカードを使って対戦。RoomPage で進行・結果ダイアログ表示
- Debug: ルートページ左下にデバッグFAB（kDebugMode時）→ FunctionsTestPage

### Youtube
デモ

### メンバー
- [梶原](https://github.com/tyumu)
- [蒲原](https://github.com/rekku0624)
- [富工](https://github.com/kuronooto)

## 環境構築
1. リポジトリをクローン:  
   SSH の場合  
   `git clone git@github.com:kuronooto/SIKAPOKE_flutter.git`  
   HTTPS の場合  
   `git clone https://github.com/kuronooto/SIKAPOKE_flutter.git`  
2. プロジェクトディレクトリに移動:  
   `cd SIKAPOKE_flutter`  
3. パッケージのインストール:  
   `flutter pub get`  
4. プロジェクトの実行（例）:
   - エミュレータで動かす（推奨・Web）  
     - 事前準備: Firebase CLI, Node.js, Java（必要に応じて）
     - Firebase 設定（初回のみ）: `flutterfire configure`（任意）
     - Functions 依存関係:  
       ```
       cd functions
       npm i
       npm run build
       cd ..
       ```
     - エミュレータ起動:  
       `firebase emulators:start --only functions,firestore,auth`
     - アプリ起動（Web例）:  
       `flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true`
   - 実機/本番で動かす（注意: デプロイ/設定済み前提）  
     - アプリ起動（例）:  
       `flutter run`
     - Functions デプロイ:  
       ```
       cd functions
       npm run build
       firebase deploy --only functions
       ```

### 補足
- USE_FIREBASE_EMULATOR は bool.fromEnvironment を使用（デフォルトは Debug=true / Release=false）
- Functions/Firestore/Auth は Web/モバイル双方で同一リージョン us-central1 を使用
- Deck 保存は saveDeck（Functions）に集約