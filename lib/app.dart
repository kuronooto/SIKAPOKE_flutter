import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'view_models/gacha_view_model.dart';
import 'views/gacha/gacha_screen.dart';
import 'views/shared/app_theme.dart' as theme;

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GachaViewModel>(
      create: (_) => GachaViewModel(),
      child: MaterialApp(
        title: 'SIKAPOKE',
        theme: theme.AppTheme.theme,
        home: const GachaScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
