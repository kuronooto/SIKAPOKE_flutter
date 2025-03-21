import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sikapoke_flutter/pages/card_page.dart';
import 'package:sikapoke_flutter/pages/battle_page.dart';
import 'package:sikapoke_flutter/pages/home_page.dart';
import 'package:sikapoke_flutter/pages/auth_page.dart';
//import 'package:mokumou_hazard/test_page.dart'';

/// ボトムナビゲーションを実装
/// 下記ページを切り替えるページ
/// - マップページ
/// - home
/// - card
/// - battle

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _selectedIndex = 0;

  void togglePage() {
    setState(() {
      _selectedIndex = 0; // マップページに遷移
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    String appBarTitle;
    switch (_selectedIndex) {
      case 0:
        page = const HomePage();
        appBarTitle = 'Home';
        break;
      case 1:
        page = const CardPage();
        appBarTitle = 'Card';
        break;
      default:
        page = const BattlePage();
        appBarTitle = 'Battle';
        break;
      // default:
      //   page = const TestPage();
      //   appBarTitle = 'TEST';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.cyan,
        //ロゴマーク画像
        // leading: Image.asset('assets/logo.png', width: 40, height: 40),
        centerTitle: true,
        title: Text(
          appBarTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // ログアウトボタン
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
        ],
      ),
      body: page,
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Card'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'Battle'),
          // BottomNavigationBarItem(
          //     icon: Icon(Icons.data_array), label: 'forTest'),
        ],
      ),
    );
  }
}
