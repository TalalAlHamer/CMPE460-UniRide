import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _passwordVisible = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // UniRide colors
  static const Color kUniRideTeal2 = Color(0xFF009DAE);
  static const Color kUniRideYellow = Color(0xFFFFC727);

  static const Color kTop = Color(0xFFE4FAFC);
  static const Color kBottom = Color(0xFFD7F3F7);

  @override
  void initState() {
    super.initState();

    // Check if user is already logged in
    _checkAuthState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  Future<void> _checkAuthState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // User is already logged in, navigate to home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(cred.user!.uid)
          .get();

      if (!userDoc.exists) {
        _showError("User profile missing.");
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showError("Invalid email or password.");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ---------- GRADIENT BACKGROUND ----------
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kTop, kBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // ---------- LOGO ANIMATION ----------
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/uniride_logo.jpg',
                          height: 140,
                          width: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ---------- TITLE ----------
                const Text(
                  "UniRide",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: kUniRideTeal2,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Connecting students for cheaper and safer rides",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),

                const SizedBox(height: 40),

                // ---------- EMAIL FIELD ----------
                _glassField(
                  controller: _emailController,
                  hint: "Email",
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),

                // ---------- PASSWORD FIELD ----------
                _glassField(
                  controller: _passwordController,
                  hint: "Password",
                  icon: Icons.lock_outline,
                  obscure: !_passwordVisible,
                  suffix: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: kUniRideTeal2,
                    ),
                    onPressed: () {
                      setState(() => _passwordVisible = !_passwordVisible);
                    },
                  ),
                ),

                const SizedBox(height: 30),

                // ---------- LOGIN BUTTON ----------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kUniRideYellow,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 6,
                      shadowColor: Colors.black38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.black87)
                        : const Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                // ---------- CREATE ACCOUNT ----------
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kUniRideTeal2, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: kUniRideTeal2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ---------- TERMS ----------
                Text(
                  "By continuing, you agree to UniRide’s Terms & Privacy Policy",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- FIXED GLASS FIELD (PERFECT ALIGNMENT) ----------
  Widget _glassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    final focusNode = FocusNode();
    
    return StatefulBuilder(
      builder: (context, setState) {
        focusNode.addListener(() {
          setState(() {});
        });

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: focusNode.hasFocus 
                ? kUniRideTeal2 
                : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(22),
                ),

                child: Row(
                  children: [
                    Icon(icon, color: kUniRideTeal2, size: 22),
                    const SizedBox(width: 12),

                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          hintText: hint,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          isCollapsed: true, // FIXES VERTICAL FLOATING
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),

                    if (suffix != null) suffix,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
