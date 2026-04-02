// ============================================================
//  signup_page.dart
//  Flutter Signup Page with Firebase Auth + Cloud Firestore
//  Supports two roles: "user" (customer) and "worker" (service provider)
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Entry point (remove if you have your own main.dart) ──────
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const MyApp());
// }

// ============================================================
//  SignupPage Widget
// ============================================================
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // ---------- Form & Controllers ----------
  final _formKey = GlobalKey<FormState>();

  final _nameController       = TextEditingController();
  final _emailController      = TextEditingController();
  final _passwordController   = TextEditingController();
  final _serviceController    = TextEditingController();
  final _experienceController = TextEditingController();

  // ---------- State ----------
  String _selectedRole = 'user'; // 'user' | 'worker'
  bool   _isLoading    = false;
  bool   _obscurePass  = true;
  String _errorMessage = '';

  // ---------- Firebase instances ----------
  final FirebaseAuth      _auth      = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  //  Core signup logic
  // ============================================================
  Future<void> _signup() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    final String uid = credential.user!.uid;

    // ✅ FIXED USER DATA
    final Map<String, dynamic> userData = {
      'uid': uid,
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'role': _selectedRole,
      'verified': _selectedRole == 'worker' ? false : true,
      'createdAt': Timestamp.now(),
    };

    if (_selectedRole == 'worker') {
      userData['service'] = _serviceController.text.trim();
      userData['experience'] =
          int.tryParse(_experienceController.text.trim()) ?? 0;
    }

    await _firestore.collection('users').doc(uid).set(userData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup successful! Please login')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  } on FirebaseAuthException catch (e) {
    setState(() => _errorMessage = e.message ?? 'Signup failed');
  } catch (e) {
    setState(() =>
        _errorMessage = 'Unexpected error occurred. Try again.');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  // ============================================================
  //  Map Firebase error codes → friendly messages
  // ============================================================
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Signup failed: $code';
    }
  }

  // ============================================================
  //  Dispose controllers to avoid memory leaks
  // ============================================================
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _serviceController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  // ============================================================
  //  Build UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ──────────────────────────────────
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign up to get started',
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // ── Name ────────────────────────────────────
                  _buildLabel('Full Name'),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Email ────────────────────────────────────
                  _buildLabel('Email Address'),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Enter your email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Password ─────────────────────────────────
                  _buildLabel('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePass,
                    decoration: _inputDecoration(
                      hint: 'Minimum 6 characters',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Password is required';
                      if (v.trim().length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Role Selection ───────────────────────────
                  _buildLabel('Select Role'),
                  _buildRoleSelector(),
                  const SizedBox(height: 16),

                  // ── Worker Extra Fields (conditional) ────────
                  if (_selectedRole == 'worker') ...[
                    _buildLabel('Service Type'),
                    _buildTextField(
                      controller: _serviceController,
                      hint: 'e.g. Electrician, Plumber, Carpenter',
                      icon: Icons.build_outlined,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Service is required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('Years of Experience'),
                    _buildTextField(
                      controller: _experienceController,
                      hint: 'e.g. 3',
                      icon: Icons.work_outline,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Experience is required';
                        }
                        if (int.tryParse(v.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Info banner for workers
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Worker accounts need admin approval before you can log in.',
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 8),

                  // ── Error Message ────────────────────────────
                  if (_errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                      ),
                    ),

                  // ── Signup Button ────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4361EE),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Already have an account ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? ',
                          style: TextStyle(color: Colors.grey)),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: Color(0xFF4361EE),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  Helper: Role selector widget (Radio tiles)
  // ============================================================
  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          _buildRoleTile(
            value: 'user',
            label: 'Customer (User)',
            subtitle: 'Looking for services',
            icon: Icons.person,
          ),
          const Divider(height: 1),
          _buildRoleTile(
            value: 'worker',
            label: 'Service Provider (Worker)',
            subtitle: 'Offering professional services',
            icon: Icons.engineering,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTile({
    required String value,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final bool selected = _selectedRole == value;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            selected ? const Color(0xFF4361EE) : Colors.grey.shade100,
        child: Icon(icon,
            color: selected ? Colors.white : Colors.grey, size: 20),
      ),
      title:
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Radio<String>(
        value: value,
        groupValue: _selectedRole,
        onChanged: (v) => setState(() => _selectedRole = v!),
        activeColor: const Color(0xFF4361EE),
      ),
      onTap: () => setState(() => _selectedRole = value),
    );
  }

  // ============================================================
  //  Helper: Label above each field
  // ============================================================
  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333)),
        ),
      );

  // ============================================================
  //  Helper: Standard text field
  // ============================================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(hint: hint, icon: icon),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF4361EE), size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF4361EE), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.8),
      ),
    );
  }
}