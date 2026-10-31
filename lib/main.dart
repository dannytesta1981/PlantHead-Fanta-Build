import 'package:flutter/material.dart';
import 'ui/native_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlantHeadFanta());
}

class PlantHeadFanta extends StatelessWidget {
  const PlantHeadFanta({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PlantHead Fanta',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff285bd7)),
      scaffoldBackgroundColor: const Color(0xffeff3fb),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff285bd7),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xffe0eaff),
      ),
    ),
    home: const NativeHome(),
  );
}
