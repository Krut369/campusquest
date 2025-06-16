import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/login_controller.dart';
import '../widgets/bottomnavigationbar.dart';
import '../modules/login/views/login.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      final isLoggedIn = Provider.of<LoginController>(context, listen: false).isLoggedIn;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isLoggedIn ? BottomBar() : LoginPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // You can change this to your theme color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Image.asset(
              'assets/logocq.png',
              width: 250,
            ),
            SizedBox(height: 20),

            // App name text
            Text(
              'CampusQuest',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0039A6), // Your specific color
              ),
            ),
        SizedBox(height: 10),
        Text(
          'ACCESS ALL WORK FROM HERE',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            letterSpacing: 1.5,
            color: Colors.grey.shade600,
          ),),
          ],
        ),
      ),
    );
  }
}
