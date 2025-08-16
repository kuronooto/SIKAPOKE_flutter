import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Firestore データアップロード用
class DataUploadPage extends StatelessWidget {

  final List<Map<String, dynamic>> cards = [
    
    {"id": 1, "name": "システム監査技術者", "type": "IT", "power": 82, "rank": "S"},
    {"id": 2, "name": "プロジェクトマネージャー", "type": "IT", "power": 69, "rank": "A"},
    {"id": 3, "name": "システムアーキテクト", "type": "IT", "power": 68, "rank": "A"},
    {"id": 4, "name": "ＩＴサービスマネージャ", "type": "IT", "power": 68, "rank": "A"},
    {
      "id": 5,
      "name": "情報セキュリティスペシャリスト",
      "type": "IT",
      "power": 77,
      "rank": "A",
    },
    {"id": 6, "name": "ネットワークスペシャリスト", "type": "IT", "power": 77, "rank": "A"},
    {"id": 7, "name": "データベーススペシャリスト", "type": "IT", "power": 77, "rank": "A"},
    {
      "id": 8,
      "name": "エンベデッドシステムスペシャリスト",
      "type": "IT",
      "power": 77,
      "rank": "A",
    },
    {"id": 9, "name": "CCNP", "type": "IT", "power": 75, "rank": "A"},
    {"id": 10, "name": "応用情報技術者", "type": "IT", "power": 75, "rank": "A"},
    {"id": 11, "name": "ディジタル技術検定 １級", "type": "IT", "power": 75, "rank": "A"},
    {"id": 12, "name": "オラクルマスターゴールド", "type": "IT", "power": 75, "rank": "A"},
    {"id": 13, "name": "PMP試験", "type": "IT", "power": 74, "rank": "A"},
    {
      "id": 14,
      "name": "XMLマスター ：プロフェッショナル",
      "type": "IT",
      "power": 74,
      "rank": "A",
    },
    {"id": 15, "name": "SUN技術者認定資格", "type": "IT", "power": 72, "rank": "A"},
    {"id": 16, "name": "MCP (上位資格)", "type": "IT", "power": 67, "rank": "B"},
    {
      "id": 17,
      "name": "CG-ARTS検定(CGエンジニア検定 エキスパート）",
      "type": "IT",
      "power": 65,
      "rank": "B",
    },
    {"id": 18, "name": "パソコン検定（Ｐ検） １級", "type": "IT", "power": 65, "rank": "B"},
    {"id": 19, "name": "パソコン整備士１級", "type": "IT", "power": 65, "rank": "B"},
    {"id": 20, "name": "ディジタル技術検定 ２級", "type": "IT", "power": 64, "rank": "B"},
    {
      "id": 21,
      "name": "ウェブデザイン技能検定 ２級",
      "type": "IT",
      "power": 64,
      "rank": "B",
    },
    {"id": 22, "name": "ITコーディネータ", "type": "IT", "power": 64, "rank": "B"},
    {"id": 23, "name": "オラクルマスターシルバー", "type": "IT", "power": 64, "rank": "B"},
    {
      "id": 24,
      "name": "QuarkXPressクリエイター能力認定試験 １級",
      "type": "IT",
      "power": 63,
      "rank": "B",
    },
    {
      "id": 25,
      "name": "Linux（LPIＣレベル２）",
      "type": "IT",
      "power": 63,
      "rank": "B",
    },
    {
      "id": 26,
      "name": "マルチメディア検定（エキスパート）",
      "type": "IT",
      "power": 62,
      "rank": "B",
    },
    {
      "id": 27,
      "name": "VBAエキスパート （スタンダード）",
      "type": "IT",
      "power": 62,
      "rank": "B",
    },
    {"id": 28, "name": "CAD利用技術者試験 １級", "type": "IT", "power": 62, "rank": "B"},
    {
      "id": 29,
      "name": "情報セキュリティ管理士認定試験",
      "type": "IT",
      "power": 61,
      "rank": "B",
    },
    {
      "id": 30,
      "name": ".com Master ダブルスター",
      "type": "IT",
      "power": 61,
      "rank": "B",
    },
    {
      "id": 31,
      "name": "MCPC モバイルシステム技術検定 １級",
      "type": "IT",
      "power": 60,
      "rank": "B",
    },
    {"id": 32, "name": "基本情報技術者試験", "type": "IT", "power": 60, "rank": "B"},
    {
      "id": 33,
      "name": "情報処理技術者能力認定試験 １級",
      "type": "IT",
      "power": 60,
      "rank": "B",
    },
    {
      "id": 34,
      "name": "C言語プログラミング能力検定試験",
      "type": "IT",
      "power": 60,
      "rank": "B",
    },
    {
      "id": 35,
      "name": "ＥＣ(電子商取引)実践能力検定 ２級",
      "type": "IT",
      "power": 59,
      "rank": "C",
    },
    {
      "id": 36,
      "name": "CG-ARTS検定 (ベーシック)",
      "type": "IT",
      "power": 58,
      "rank": "C",
    },
    {"id": 37, "name": "ソフトウェア品質技術者中級", "type": "IT", "power": 58, "rank": "C"},
    {
      "id": 38,
      "name": "情報処理技術者能力認定試験 ２級",
      "type": "IT",
      "power": 57,
      "rank": "C",
    },
    {
      "id": 39,
      "name": "情報処理技術者能力認定試験 ３級",
      "type": "IT",
      "power": 57,
      "rank": "C",
    },
    {
      "id": 40,
      "name": "CIW ファンデーション（Web Foundations Associate）",
      "type": "IT",
      "power": 57,
      "rank": "C",
    },
    {
      "id": 41,
      "name": "XMLマスター ：ベーシック",
      "type": "IT",
      "power": 56,
      "rank": "C",
    },
    {
      "id": 42,
      "name": "ウェブデザイン技能検定 ３級",
      "type": "IT",
      "power": 56,
      "rank": "C",
    },
    {"id": 43, "name": "文書情報管理士１級", "type": "IT", "power": 56, "rank": "C"},
    {"id": 44, "name": "パソコン検定（Ｐ検）２級", "type": "IT", "power": 56, "rank": "C"},
    {"id": 45, "name": "ソフトウェア品質技術者初級", "type": "IT", "power": 56, "rank": "C"},
    {"id": 46, "name": "MCP(基本資格)", "type": "IT", "power": 56, "rank": "C"},
    {"id": 47, "name": "ITパスポート試験", "type": "IT", "power": 56, "rank": "C"},
    {"id": 48, "name": "情報活用試験（J検） １級", "type": "IT", "power": 56, "rank": "C"},
    {"id": 49, "name": "情報検索応用能力試験 ２級", "type": "IT", "power": 56, "rank": "C"},
    {"id": 50, "name": "ディジタル技術検定 ３級", "type": "IT", "power": 55, "rank": "C"},
    {
      "id": 51,
      "name": "情報システム試験（J検） ＳＥ認定/ＰＧ認定",
      "type": "IT",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 52,
      "name": "CADトレース技能審査 初級・中級",
      "type": "IT",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 53,
      "name": "IT検証技術者認定試験 エントリーレベル１と２",
      "type": "IT",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 54,
      "name": "JSTQB認定テスト技術者資格認定試験 Foundation Level",
      "type": "IT",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 55,
      "name": "情報セキュリティ初級認定試験",
      "type": "IT",
      "power": 55,
      "rank": "C",
    },
    {"id": 56, "name": "電子メール活用能力検定", "type": "IT", "power": 55, "rank": "C"},
    {
      "id": 57,
      "name": "Turbolinux技術者認定試験 Turbo-CE",
      "type": "IT",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 58,
      "name": "VBAエキスパート （ベーシック）",
      "type": "IT",
      "power": 55,
      "rank": "C",
    },
    {"id": 59, "name": "文書情報管理士２級", "type": "IT", "power": 54, "rank": "C"},
    {"id": 60, "name": "Web検定", "type": "IT", "power": 54, "rank": "C"},
    {"id": 61, "name": "パソコン整備士２級", "type": "IT", "power": 54, "rank": "C"},
    {
      "id": 62,
      "name": "ＥＣ(電子商取引)実践能力検定 ３級",
      "type": "IT",
      "power": 53,
      "rank": "C",
    },
    {"id": 63, "name": "情報活用試験（J検）２級", "type": "IT", "power": 53, "rank": "C"},
    {
      "id": 64,
      "name": "MCPC モバイルシステム技術検定 ２級",
      "type": "IT",
      "power": 53,
      "rank": "C",
    },
    {"id": 65, "name": "情報デザイン試験（J検）", "type": "IT", "power": 52, "rank": "C"},
    {
      "id": 66,
      "name": "Linux（LPIＣレベル１）",
      "type": "IT",
      "power": 52,
      "rank": "C",
    },
    {
      "id": 67,
      "name": ".com Master シングルスター",
      "type": "IT",
      "power": 52,
      "rank": "C",
    },
    {"id": 68, "name": "CAD利用技術者試験 ２級", "type": "IT", "power": 52, "rank": "C"},
    {"id": 69, "name": "文書デザイン検定", "type": "IT", "power": 49, "rank": "D"},
    {"id": 70, "name": "情報活用試験（J検）３級", "type": "IT", "power": 49, "rank": "D"},
    {"id": 71, "name": "日商ＰＣ検定 ３級", "type": "IT", "power": 49, "rank": "D"},
    {
      "id": 72,
      "name": "マイクロソフト オフィススペシャリストマスター",
      "type": "IT",
      "power": 48,
      "rank": "D",
    },
    {"id": 73, "name": "パソコン検定（Ｐ検）３級", "type": "IT", "power": 48, "rank": "D"},
    {"id": 74, "name": "MCPCケータイ実務検定", "type": "IT", "power": 48, "rank": "D"},
    {"id": 75, "name": "情報検索基礎能力試験", "type": "IT", "power": 47, "rank": "D"},
    {
      "id": 76,
      "name": "ハンターライセンス",
      "type": "IT",
      "power": 20,
      "rank": "D",
    },
    {"id": 77, "name": "MOS（スペッシャリスト）", "type": "IT", "power": 47, "rank": "D"},
    {"id": 78, "name": "中国語検定1級", "type": "語学", "power": 78, "rank": "A"},
    {"id": 79, "name": "草むしり検定2級", "type": "語学", "power": 82, "rank": "S"},
    {"id": 80, "name": "草むしり検定5級", "type": "語学", "power": 20, "rank": "D"},
    {
      "id": 81,
      "name": "JTA公認翻訳専門職資格試験",
      "type": "語学",
      "power": 77,
      "rank": "A",
    },
    {"id": 82, "name": "ドイツ語技能検定 １級", "type": "語学", "power": 77, "rank": "A"},
    {
      "id": 83,
      "name": "ほんやく検定（JTF） 実用レベル２級",
      "type": "語学",
      "power": 77,
      "rank": "A",
    },
    {"id": 84, "name": "ハングル能力検定試験 ２級", "type": "語学", "power": 77, "rank": "A"},
    {"id": 85, "name": "知的財産翻訳検定 １級", "type": "語学", "power": 75, "rank": "A"},
    {"id": 86, "name": "グレッグ英文速記公式検定", "type": "語学", "power": 74, "rank": "A"},
    {"id": 87, "name": "実用英語技能検定1級", "type": "語学", "power": 74, "rank": "A"},
    {
      "id": 88,
      "name": "国際英検G-TELP レベル1",
      "type": "語学",
      "power": 74,
      "rank": "A",
    },
    {"id": 89, "name": "通訳案内士", "type": "語学", "power": 73, "rank": "A"},
    {"id": 90, "name": "実用英語技能検定準1級", "type": "語学", "power": 69, "rank": "B"},
    {"id": 91, "name": "中日通検", "type": "語学", "power": 68, "rank": "B"},
    {
      "id": 92,
      "name": "TOEIC TEST７００点",
      "type": "語学",
      "power": 67,
      "rank": "B",
    },
    {"id": 93, "name": "スペイン語技能検定 ３級", "type": "語学", "power": 66, "rank": "B"},
    {"id": 94, "name": "実用イタリア語検定 ３級", "type": "語学", "power": 66, "rank": "B"},
    {"id": 95, "name": "ドイツ語技能検定 準１級", "type": "語学", "power": 65, "rank": "B"},
    {
      "id": 96,
      "name": "ほんやく検定（JTF） 実用レベル３級",
      "type": "語学",
      "power": 65,
      "rank": "B",
    },
    {"id": 97, "name": "中国語検定試験 ２級", "type": "語学", "power": 65, "rank": "B"},
    {"id": 98, "name": "実用フランス語検定 ２級", "type": "語学", "power": 65, "rank": "B"},
    {
      "id": 99,
      "name": "国際英検G-TELP レベル２",
      "type": "語学",
      "power": 65,
      "rank": "B",
    },
    {
      "id": 100,
      "name": "日本語能力試験(JLPT)N３",
      "type": "語学",
      "power": 64,
      "rank": "B",
    },
    {"id": 101, "name": "知的財産翻訳検定 ２級", "type": "語学", "power": 63, "rank": "B"},
    {"id": 102, "name": "中国語検定試験３級", "type": "語学", "power": 56, "rank": "C"},
    {"id": 103, "name": "実用英語検定（英検）２級", "type": "語学", "power": 55, "rank": "C"},
    {
      "id": 104,
      "name": "ハングル能力検定試験 ３級",
      "type": "語学",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 105,
      "name": "実用イタリア語検定４級・５級",
      "type": "語学",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 106,
      "name": "国際英検G-TELP レベル３",
      "type": "語学",
      "power": 55,
      "rank": "C",
    },
    {"id": 107, "name": "漢字検定 ３級", "type": "語学", "power": 49, "rank": "D"},
    {
      "id": 108,
      "name": "国際英検G-TELP レベル4",
      "type": "語学",
      "power": 49,
      "rank": "D",
    },
    {"id": 109, "name": "スペイン語技能検定 ６級", "type": "語学", "power": 48, "rank": "D"},
    {"id": 110, "name": "実用英語検定（英検）３級", "type": "語学", "power": 46, "rank": "D"},
    {"id": 111, "name": "公認会計士", "type": "ビジネス", "power": 82, "rank": "S"},
    {"id": 112, "name": "ＭＢＡ（経営学修士）", "type": "ビジネス", "power": 79, "rank": "A"},
    {"id": 113, "name": "税理士", "type": "ビジネス", "power": 78, "rank": "A"},
    {"id": 114, "name": "アクチュアリー", "type": "ビジネス", "power": 78, "rank": "A"},
    {
      "id": 115,
      "name": "国際会計検定（BATIC）",
      "type": "ビジネス",
      "power": 77,
      "rank": "A",
    },
    {"id": 116, "name": "中小企業診断士", "type": "ビジネス", "power": 76, "rank": "A"},
    {
      "id": 117,
      "name": "CFA協会認定証券アナリスト",
      "type": "ビジネス",
      "power": 75,
      "rank": "A",
    },
    {
      "id": 118,
      "name": "証券アナリスト( CMA)",
      "type": "ビジネス",
      "power": 72,
      "rank": "A",
    },
    {"id": 119, "name": "農業協同組合監査士", "type": "ビジネス", "power": 72, "rank": "A"},
    {
      "id": 120,
      "name": "公認内部監査人（CIA）",
      "type": "ビジネス",
      "power": 70,
      "rank": "A",
    },
    {
      "id": 121,
      "name": "ＣＦＰ / FP技能士１級",
      "type": "ビジネス",
      "power": 68,
      "rank": "B",
    },
    {
      "id": 122,
      "name": "金融窓口サービス技能検定 １級",
      "type": "ビジネス",
      "power": 65,
      "rank": "B",
    },
    {"id": 123, "name": "証券外務員 １種", "type": "ビジネス", "power": 65, "rank": "B"},
    {
      "id": 124,
      "name": "ビジネス能力検定試験（Ｂ検）１級",
      "type": "ビジネス",
      "power": 65,
      "rank": "B",
    },
    {"id": 125, "name": "販売士１級", "type": "ビジネス", "power": 64, "rank": "B"},
    {"id": 126, "name": "ＰＲプランナー", "type": "ビジネス", "power": 64, "rank": "B"},
    {
      "id": 127,
      "name": "ディスクロージャー経理実務検定（基礎編）",
      "type": "ビジネス",
      "power": 63,
      "rank": "B",
    },
    {
      "id": 128,
      "name": "IFRS検定（国際会計基準検定）",
      "type": "ビジネス",
      "power": 63,
      "rank": "B",
    },
    {"id": 129, "name": "日商簿記検定２級", "type": "ビジネス", "power": 63, "rank": "B"},
    {
      "id": 130,
      "name": "金融窓口サービス技能検定 ２級",
      "type": "ビジネス",
      "power": 63,
      "rank": "B",
    },
    {
      "id": 131,
      "name": "ビジネス会計検定 ２級",
      "type": "ビジネス",
      "power": 63,
      "rank": "B",
    },
    {"id": 132, "name": "銀行業務検定 ２級", "type": "ビジネス", "power": 63, "rank": "B"},
    {"id": 133, "name": "SC経営士", "type": "ビジネス", "power": 63, "rank": "B"},
    {"id": 134, "name": "経営学検定中級", "type": "ビジネス", "power": 62, "rank": "B"},
    {
      "id": 135,
      "name": "マーケティング・ビジネス実務検定 Ｂ級",
      "type": "ビジネス",
      "power": 62,
      "rank": "B",
    },
    {
      "id": 136,
      "name": "会計ソフト実務能力試験 1級(旧PC財務関係主任者)",
      "type": "ビジネス",
      "power": 61,
      "rank": "B",
    },
    {
      "id": 137,
      "name": "税務会計能力検定１級（税務会計検定）",
      "type": "ビジネス",
      "power": 61,
      "rank": "B",
    },
    {
      "id": 138,
      "name": "電子化ファイリング検定 Ａ級",
      "type": "ビジネス",
      "power": 61,
      "rank": "B",
    },
    {
      "id": 139,
      "name": "電卓技能検定試験 １級",
      "type": "ビジネス",
      "power": 61,
      "rank": "B",
    },
    {"id": 140, "name": "DCプランナー１級", "type": "ビジネス", "power": 60, "rank": "B"},
    {
      "id": 141,
      "name": "ビジネス・キャリア検定試験 ２級",
      "type": "ビジネス",
      "power": 60,
      "rank": "B",
    },
    {
      "id": 142,
      "name": "プロフェッショナル CFO",
      "type": "ビジネス",
      "power": 60,
      "rank": "B",
    },
    {"id": 143, "name": "貸金業務取扱主任者", "type": "ビジネス", "power": 59, "rank": "C"},
    {"id": 144, "name": "銀行業務検定 ３級", "type": "ビジネス", "power": 58, "rank": "C"},
    {"id": 145, "name": "DCアドバイザー", "type": "ビジネス", "power": 57, "rank": "C"},
    {"id": 146, "name": "スタンダード CFO", "type": "ビジネス", "power": 57, "rank": "C"},
    {
      "id": 147,
      "name": "FASS(経理・財務スキル検定)レベルC",
      "type": "ビジネス",
      "power": 57,
      "rank": "C",
    },
    {
      "id": 148,
      "name": "電子化ファイリング検定 Ｂ級",
      "type": "ビジネス",
      "power": 55,
      "rank": "C",
    },
    {"id": 149, "name": "販売士２級", "type": "ビジネス", "power": 55, "rank": "C"},
    {"id": 150, "name": "日商簿記検定 ３級", "type": "ビジネス", "power": 55, "rank": "C"},
    {
      "id": 151,
      "name": "税務会計能力検定２級（税務会計検定）",
      "type": "ビジネス",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 152,
      "name": "ビジネス能力検定（Ｂ検）２級",
      "type": "ビジネス",
      "power": 55,
      "rank": "C",
    },
    {
      "id": 153,
      "name": "マーケティング・ビジネス実務検定 Ｃ級",
      "type": "ビジネス",
      "power": 55,
      "rank": "C",
    },
    {"id": 154, "name": "DCプランナー２級", "type": "ビジネス", "power": 54, "rank": "C"},
    {
      "id": 155,
      "name": "商業経済検定試験 １級",
      "type": "ビジネス",
      "power": 54,
      "rank": "C",
    },
    {
      "id": 156,
      "name": "会計ソフト実務能力試験 ２級（旧財務会計主任者)",
      "type": "ビジネス",
      "power": 53,
      "rank": "C",
    },
    {
      "id": 157,
      "name": "ビジネスキャリア検定 ３級",
      "type": "ビジネス",
      "power": 53,
      "rank": "C",
    },
    {"id": 158, "name": "准ＰＲプランナー", "type": "ビジネス", "power": 53, "rank": "C"},
    {
      "id": 159,
      "name": "全経計算実務能力検定試験 ３級",
      "type": "ビジネス",
      "power": 53,
      "rank": "C",
    },
    {
      "id": 160,
      "name": "認定 BCM-RM(事業継続経営リスクマネジャー)資格",
      "type": "ビジネス",
      "power": 52,
      "rank": "C",
    },
    {
      "id": 161,
      "name": "ビジネス会計検定 ３級",
      "type": "ビジネス",
      "power": 51,
      "rank": "C",
    },
    {
      "id": 162,
      "name": "シニアリスクコンサルタント",
      "type": "ビジネス",
      "power": 51,
      "rank": "C",
    },
    {"id": 163, "name": "変額保険販売資格試験", "type": "ビジネス", "power": 51, "rank": "C"},
    {
      "id": 164,
      "name": "コンピュータ会計能力検定 ２級",
      "type": "ビジネス",
      "power": 50,
      "rank": "C",
    },
    {
      "id": 165,
      "name": "商業経済検定試験 ３級",
      "type": "ビジネス",
      "power": 48,
      "rank": "D",
    },
    {
      "id": 166,
      "name": "ビジネス能力検定(B検) ３級",
      "type": "ビジネス",
      "power": 48,
      "rank": "D",
    },
    {"id": 167, "name": "ＰＲプランナー補", "type": "ビジネス", "power": 48, "rank": "D"},
    {
      "id": 168,
      "name": "ファイナンシャル・プランニング技能士３級",
      "type": "ビジネス",
      "power": 47,
      "rank": "D",
    },
    {"id": 169, "name": "販売士３級", "type": "ビジネス", "power": 47, "rank": "D"},
    {
      "id": 170,
      "name": "オレオレ詐欺２級",
      "type": "ビジネス",
      "power": 20,
      "rank": "D",
    },
    {
      "id": 171,
      "name": "住宅ローンアドバイザー",
      "type": "ビジネス",
      "power": 46,
      "rank": "D",
    },
// ...既存cardsリスト...
//new cards to be added
{
 "id": 201,
      "name": "ハンターライセンス",
      "type": "IT",
      "power": 20,
      "rank": "D",
},
{
  "id": 202,
"name": "草むしり検定2級", "type": "語学", "power": 82, "rank": "S"
},
{
  "id": 203,
   "name": "草むしり検定5級", "type": "語学", "power": 20, "rank": "D"
},
{
  "id": 204,
  "name": "オレオレ詐欺２級",
      "type": "ビジネス",
      "power": 20,
      "rank": "D",
},
// ...既存cardsリストの末尾
  ];

  Future<void> uploadData() async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (useEmu) {
      try { functions.useFunctionsEmulator('localhost', 5001); } catch (_) {}
      try { FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080); } catch (_) {}
      try { await FirebaseAuth.instance.useAuthEmulator('localhost', 9099); } catch (_) {} // 追加
    }

    // 追加: 認証を保証（未ログインなら匿名、ログイン済みならトークン更新）
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    } else {
      await FirebaseAuth.instance.currentUser!.getIdToken(true);
    }

    try {
      await functions.httpsCallable('adminUpsertCards').call(<String, dynamic>{ 'cards': cards });
    } on FirebaseFunctionsException catch (e) {
      // Web での原因特定用に details を表示
      debugPrint('adminUpsertCards error code=${e.code} message=${e.message} details=${e.details}');
      rethrow;
    }
  }

  // 追加: 誤操作防止の確認
  Future<void> _confirmAndUpload(BuildContext context) async {
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    if (!useEmu) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('本番へカードを投入します'),
          content: const Text('本当に続行しますか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('投入する'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await uploadData();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('カードマスタを投入しました')));
    } on FirebaseFunctionsException catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投入失敗: ${e.code} ${e.message ?? ""}')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投入失敗(その他): $e')),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    const useEmu = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: kDebugMode);
    return Scaffold(
      appBar: AppBar(title: Text('Data Upload${useEmu ? " (emu)" : " (prod)"}')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _confirmAndUpload(context),
          child: const Text('Upload Data'),
        ),
      ),
    );
  }
}
