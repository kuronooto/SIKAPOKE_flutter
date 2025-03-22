import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firestore データアップロード用
class DataUploadPage extends StatelessWidget {
  final List<Map<String, dynamic>> cards = [
    {"name": "ITストラテジスト", "type": "IT・パソコン・情報技術", "power": 71, "rank": "S"},
    {"name": "システム監査技術者", "type": "IT・パソコン・情報技術", "power": 70, "rank": "S"},
    {"name": "プロジェクトマネージャー", "type": "IT・パソコン・情報技術", "power": 69, "rank": "A"},
    {"name": "システムアーキテクト", "type": "IT・パソコン・情報技術", "power": 68, "rank": "A"},
    {"name": "ITサービスマネージャ", "type": "IT・パソコン・情報技術", "power": 68, "rank": "A"},
    {
      "name": "情報セキュリティスペシャリスト",
      "type": "IT・パソコン・情報技術",
      "power": 67,
      "rank": "A",
    },
    {"name": "ネットワークスペシャリスト", "type": "IT・パソコン・情報技術", "power": 67, "rank": "A"},
    {"name": "データベーススペシャリスト", "type": "IT・パソコン・情報技術", "power": 67, "rank": "A"},
    {
      "name": "エンベデッドシステムスペシャリスト",
      "type": "IT・パソコン・情報技術",
      "power": 67,
      "rank": "A",
    },
    {"name": "CCNP", "type": "IT・パソコン・情報技術", "power": 65, "rank": "A"},
    {"name": "応用情報技術者", "type": "IT・パソコン・情報技術", "power": 65, "rank": "A"},
    {"name": "ディジタル技術検定 １級", "type": "IT・パソコン・情報技術", "power": 65, "rank": "A"},
    {"name": "オラクルマスターゴールド", "type": "IT・パソコン・情報技術", "power": 65, "rank": "A"},
    {"name": "PMP試験", "type": "IT・パソコン・情報技術", "power": 64, "rank": "A"},
    {
      "name": "XMLマスター ：プロフェッショナル",
      "type": "IT・パソコン・情報技術",
      "power": 64,
      "rank": "A",
    },
    {"name": "SUN技術者認定資格", "type": "IT・パソコン・情報技術", "power": 62, "rank": "A"},
    {"name": "MCP (上位資格)", "type": "IT・パソコン・情報技術", "power": 57, "rank": "B"},
    {
      "name": "CG-ARTS検定(CGエンジニア検定 エキスパート）",
      "type": "IT・パソコン・情報技術",
      "power": 55,
      "rank": "B",
    },
    {"name": "パソコン検定（Ｐ検） １級", "type": "IT・パソコン・情報技術", "power": 55, "rank": "B"},
    {"name": "パソコン整備士１級", "type": "IT・パソコン・情報技術", "power": 55, "rank": "B"},
    {"name": "ディジタル技術検定 ２級", "type": "IT・パソコン・情報技術", "power": 54, "rank": "B"},
    {
      "name": "ウェブデザイン技能検定 ２級",
      "type": "IT・パソコン・情報技術",
      "power": 54,
      "rank": "B",
    },
    {"name": "ITコーディネータ", "type": "IT・パソコン・情報技術", "power": 54, "rank": "B"},
    {"name": "オラクルマスターシルバー", "type": "IT・パソコン・情報技術", "power": 54, "rank": "B"},
    {
      "name": "QuarkXPressクリエイター能力認定試験 １級",
      "type": "IT・パソコン・情報技術",
      "power": 53,
      "rank": "B",
    },
    {
      "name": "Linux（LPIＣレベル２）",
      "type": "IT・パソコン・情報技術",
      "power": 53,
      "rank": "B",
    },
    {
      "name": "マルチメディア検定（エキスパート）",
      "type": "IT・パソコン・情報技術",
      "power": 52,
      "rank": "B",
    },
    {
      "name": "VBAエキスパート （スタンダード）",
      "type": "IT・パソコン・情報技術",
      "power": 52,
      "rank": "B",
    },
    {"name": "CAD利用技術者試験 １級", "type": "IT・パソコン・情報技術", "power": 52, "rank": "B"},
    {
      "name": "情報セキュリティ管理士認定試験",
      "type": "IT・パソコン・情報技術",
      "power": 51,
      "rank": "B",
    },
    {
      "name": ".com Master ダブルスター",
      "type": "IT・パソコン・情報技術",
      "power": 51,
      "rank": "B",
    },
    {
      "name": "MCPC モバイルシステム技術検定 １級",
      "type": "IT・パソコン・情報技術",
      "power": 50,
      "rank": "B",
    },
    {"name": "基本情報技術者試験", "type": "IT・パソコン・情報技術", "power": 50, "rank": "B"},
    {
      "name": "情報処理技術者能力認定試験 １級",
      "type": "IT・パソコン・情報技術",
      "power": 50,
      "rank": "B",
    },
    {
      "name": "C言語プログラミング能力検定試験",
      "type": "IT・パソコン・情報技術",
      "power": 50,
      "rank": "B",
    },
    {
      "name": "ＥＣ(電子商取引)実践能力検定 ２級",
      "type": "IT・パソコン・情報技術",
      "power": 49,
      "rank": "C",
    },
    {
      "name": "CG-ARTS検定 (ベーシック)",
      "type": "IT・パソコン・情報技術",
      "power": 48,
      "rank": "C",
    },
    {"name": "ソフトウェア品質技術者中級", "type": "IT・パソコン・情報技術", "power": 48, "rank": "C"},
    {
      "name": "情報処理技術者能力認定試験 ２級",
      "type": "IT・パソコン・情報技術",
      "power": 47,
      "rank": "C",
    },
    {
      "name": "情報処理技術者能力認定試験 ３級",
      "type": "IT・パソコン・情報技術",
      "power": 47,
      "rank": "C",
    },
    {
      "name": "CIW ファンデーション（Web Foundations Associate）",
      "type": "IT・パソコン・情報技術",
      "power": 47,
      "rank": "C",
    },
    {
      "name": "XMLマスター ：ベーシック",
      "type": "IT・パソコン・情報技術",
      "power": 46,
      "rank": "C",
    },
    {
      "name": "ウェブデザイン技能検定 ３級",
      "type": "IT・パソコン・情報技術",
      "power": 46,
      "rank": "C",
    },
    {"name": "文書情報管理士１級", "type": "IT・パソコン・情報技術", "power": 46, "rank": "C"},
    {"name": "パソコン検定（Ｐ検）２級", "type": "IT・パソコン・情報技術", "power": 46, "rank": "C"},
    {"name": "ソフトウェア品質技術者初級", "type": "IT・パソコン・情報技術", "power": 46, "rank": "C"},
    {"name": "MCP(基本資格)", "type": "IT・パソコン・情報技術", "power": 46, "rank": "C"},
    {"name": "ITパスポート試験", "type": "IT・パソコン・情報技術", "power": 46, "rank": "C"},
    {"name": "情報活用試験（J検） １級", "type": "IT・パソコン・情報技術", "power": 46, "rank": "C"},
    {"name": "情報検索応用能力試験 ２級", "type": "IT・パソコン・情報技術", "power": 46, "rank": "C"},
    {"name": "ディジタル技術検定 ３級", "type": "IT・パソコン・情報技術", "power": 45, "rank": "C"},
    {
      "name": "情報システム試験（J検） ＳＥ認定/ＰＧ認定",
      "type": "IT・パソコン・情報技術",
      "power": 45,
      "rank": "C",
    },
    {
      "name": "CADトレース技能審査 初級・中級",
      "type": "IT・パソコン・情報技術",
      "power": 45,
      "rank": "C",
    },
    {
      "name": "IT検証技術者認定試験 エントリーレベル１と２",
      "type": "IT・パソコン・情報技術",
      "power": 45,
      "rank": "C",
    },
    {
      "name": "JSTQB認定テスト技術者資格認定試験 Foundation Level",
      "type": "IT・パソコン・情報技術",
      "power": 45,
      "rank": "C",
    },
    {
      "name": "情報セキュリティ初級認定試験",
      "type": "IT・パソコン・情報技術",
      "power": 45,
      "rank": "C",
    },
    {"name": "電子メール活用能力検定", "type": "IT・パソコン・情報技術", "power": 45, "rank": "C"},
    {
      "name": "Turbolinux技術者認定試験 Turbo-CE",
      "type": "IT・パソコン・情報技術",
      "power": 45,
      "rank": "C",
    },
    {
      "name": "VBAエキスパート （ベーシック）",
      "type": "IT・パソコン・情報技術",
      "power": 45,
      "rank": "C",
    },
    {"name": "文書情報管理士２級", "type": "IT・パソコン・情報技術", "power": 44, "rank": "C"},
    {"name": "Web検定", "type": "IT・パソコン・情報技術", "power": 44, "rank": "C"},
    {"name": "パソコン整備士２級", "type": "IT・パソコン・情報技術", "power": 44, "rank": "C"},
    {
      "name": "ＥＣ(電子商取引)実践能力検定 ３級",
      "type": "IT・パソコン・情報技術",
      "power": 43,
      "rank": "C",
    },
    {"name": "情報活用試験（J検）２級", "type": "IT・パソコン・情報技術", "power": 43, "rank": "C"},
    {
      "name": "MCPC モバイルシステム技術検定 ２級",
      "type": "IT・パソコン・情報技術",
      "power": 43,
      "rank": "C",
    },
    {"name": "情報デザイン試験（J検）", "type": "IT・パソコン・情報技術", "power": 42, "rank": "C"},
    {
      "name": "Linux（LPIＣレベル１）",
      "type": "IT・パソコン・情報技術",
      "power": 42,
      "rank": "C",
    },
    {
      "name": ".com Master シングルスター",
      "type": "IT・パソコン・情報技術",
      "power": 42,
      "rank": "C",
    },
    {"name": "CAD利用技術者試験 ２級", "type": "IT・パソコン・情報技術", "power": 42, "rank": "C"},
    {"name": "文書デザイン検定", "type": "IT・パソコン・情報技術", "power": 39, "rank": "D"},
    {"name": "情報活用試験（J検）３級", "type": "IT・パソコン・情報技術", "power": 39, "rank": "D"},
    {"name": "日商ＰＣ検定 ３級", "type": "IT・パソコン・情報技術", "power": 39, "rank": "D"},
    {
      "name": "マイクロソフト オフィススペシャリストマスター",
      "type": "IT・パソコン・情報技術",
      "power": 38,
      "rank": "D",
    },
    {"name": "パソコン検定（Ｐ検）３級", "type": "IT・パソコン・情報技術", "power": 38, "rank": "D"},
    {"name": "MCPCケータイ実務検定", "type": "IT・パソコン・情報技術", "power": 38, "rank": "D"},
    {"name": "情報検索基礎能力試験", "type": "IT・パソコン・情報技術", "power": 37, "rank": "D"},
    {
      "name": "Word/Excel文書処理技能認定試験３級",
      "type": "IT・パソコン・情報技術",
      "power": 37,
      "rank": "D",
    },
    {"name": "MOS（スペッシャリスト）", "type": "IT・パソコン・情報技術", "power": 37, "rank": "D"},
  ];

  Future<void> uploadData() async {
    final collection = FirebaseFirestore.instance.collection('cards');
    for (var card in cards) {
      await collection.add(card);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Data Upload')),
      body: Center(
        child: ElevatedButton(
          onPressed: uploadData,
          child: Text('Upload Data'),
        ),
      ),
    );
  }
}
