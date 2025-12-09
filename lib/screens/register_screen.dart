import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;

  // Colors (matching UniRide)
  static const Color kScreenTeal = Color(0xFFE0F9FB);
  static const Color kUniRideTeal2 = Color(0xFF009DAE);
  static const Color kUniRideYellow = Color(0xFFFFC727);

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _register() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();
    String confirm = _confirmController.text.trim();

    // VALIDATION
    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }

    if (!email.contains("@") || !email.contains(".")) {
      _showError("Please enter a valid email.");
      return;
    }

    if (password.length < 6) {
      _showError("Password must be at least 6 characters.");
      return;
    }

    if (password != confirm) {
      _showError("Passwords do not match.");
      return;
    }

    setState(() => _loading = true);

    try {
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await FirebaseFirestore.instance
          .collection("users")
          .doc(cred.user!.uid)
          .set({
            "name": name,
            "email": email,
            "phone": phone,
            "uid": cred.user!.uid,
            "createdAt": Timestamp.now(),
          });

      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code == "email-already-in-use") {
        _showError("An account already exists for this email.");
      } else if (e.code == "invalid-email") {
        _showError("Invalid email format.");
      } else if (e.code == "weak-password") {
        _showError("Password is too weak.");
      } else {
        _showError(e.message ?? "Registration failed. Try again.");
      }
    } catch (_) {
      _showError("Something went wrong. Try again.");
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenTeal,

      // ---------------- APP BAR WITH BACK BUTTON ----------------
      appBar: AppBar(
        backgroundColor: kScreenTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kUniRideTeal2,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Register",
          style: TextStyle(
            color: kUniRideTeal2,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ---------------- BODY ----------------
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 20),

                const Text(
                  "Create an Account",
                  style: TextStyle(
                    color: kUniRideTeal2,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                _input("Full Name", Icons.person, _nameController),
                const SizedBox(height: 16),

                _input("Email", Icons.email_outlined, _emailController),
                const SizedBox(height: 16),

                _input("Phone Number", Icons.phone, _phoneController),
                const SizedBox(height: 16),

                _input(
                  "Password",
                  Icons.lock_outline,
                  _passwordController,
                  obscure: true,
                ),
                const SizedBox(height: 16),

                _input(
                  "Confirm Password",
                  Icons.lock_outline,
                  _confirmController,
                  obscure: true,
                ),

                const SizedBox(height: 30),

                // ---------------- REGISTER BUTTON ----------------
                GestureDetector(
                  onTap: _loading ? null : _register,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: kUniRideYellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              "Register →",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(
                      color: kUniRideTeal2,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- INPUT FIELD ----------------
  Widget _input(
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kUniRideTeal2.withValues(alpha: 0.4)),
      ),
      child: TextField(
        obscureText: obscure,
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: kUniRideTeal2),
          border: InputBorder.none,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
