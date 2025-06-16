import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../controllers/login_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isPasswordVisible = false;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginController = Provider.of<LoginController>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenHeight * 0.03,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated Back Button (Commented out as per original code)
                  // IconButton(
                  //   icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
                  //   onPressed: () => Navigator.pop(context),
                  // ).animate().fadeIn(duration: 300.ms),

                  // Logo and Welcome Section
                  Center(
                    child: Column(
                      children: [
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            'assets/logocq.png',
                            height: screenHeight * 0.12,
                            width: screenHeight * 0.12,
                          ),
                        ).animate().scale(duration: 500.ms, delay: 200.ms),
                        SizedBox(height: screenHeight * 0.03),
                        Text(
                          'Welcome to CQ',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth * 0.07,
                            color: const Color(0xFF0039A6),
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                        SizedBox(height: screenHeight * 0.015),
                        Text(
                          'ACCESS ALL WORK FROM HERE',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: screenWidth * 0.04,
                            letterSpacing: 1.5,
                            color: Colors.grey.shade600,
                          ),
                        ).animate().fadeIn(duration: 700.ms, delay: 400.ms),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.05),

                  // Email TextField with Validation
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => loginController.setEmail(value),
                    decoration: _buildInputDecoration('Email Address', screenWidth, screenHeight),
                    validator: (value) =>
                    _validateEmail(value) ? null : 'Enter a valid email',
                  ).animate().fadeIn(duration: 800.ms, delay: 500.ms),
                  SizedBox(height: screenHeight * 0.03),

                  // Phone Number TextField
                  TextFormField(
                    controller: _phoneController,
                    obscureText: !_isPasswordVisible,
                    keyboardType: TextInputType.phone,
                    onChanged: (value) => loginController.setPhone(value),
                    decoration: _buildInputDecoration(
                      'Phone Number (as Password)',
                      screenWidth,
                      screenHeight,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: screenWidth * 0.06,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) =>
                    value != null && value.length >= 10
                        ? null
                        : 'Enter a valid phone number',
                  ).animate().fadeIn(duration: 900.ms, delay: 600.ms),

                  // Forgot Password Link
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: TextButton(
                  //     onPressed: () {
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         const SnackBar(
                  //           content: Text('Forgot Password feature coming soon!'),
                  //         ),
                  //       );
                  //     },
                  //     child: Text(
                  //       'Forgot Password?',
                  //       style: TextStyle(
                  //         fontSize: screenWidth * 0.035,
                  //         color: Colors.grey.shade700,
                  //       ),
                  //     ),
                  //   ),
                  // ).animate().fadeIn(duration: 1000.ms, delay: 700.ms),
                  SizedBox(height: screenHeight * 0.04),

                  // Login Button with Responsive Width
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          bool isLoggedIn = await loginController.login(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isLoggedIn
                                    ? 'Login Successful!'
                                    : loginController.errorMessage,
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: isLoggedIn
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.25,
                          vertical: screenHeight * 0.02,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.045,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ).animate().fadeIn(duration: 1100.ms, delay: 800.ms),
                  ),
                  SizedBox(height: screenHeight * 0.06),

                  // Bottom Illustration
                  Center(
                    child: Image.asset(
                      'assets/login_illustration.png',
                      width: screenWidth * 0.8,
                      height: screenHeight * 0.25,
                      fit: BoxFit.contain,
                    ).animate().fadeIn(duration: 1200.ms, delay: 900.ms),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for input decoration with screenWidth and screenHeight parameters
  InputDecoration _buildInputDecoration(
      String hintText,
      double screenWidth,
      double screenHeight, { // Ensure both parameters are included
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: screenWidth * 0.04, color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.grey.shade100,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: const Color(0xFF6D28D9), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.02,
      ),
    );
  }

  // Email validation helper method
  bool _validateEmail(String? email) {
    if (email == null) return false;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
}

// Extension for capitalizing first letter
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}