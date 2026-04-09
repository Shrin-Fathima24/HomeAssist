import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpVerificationPage extends StatefulWidget {
  final String bookingId;

  const OtpVerificationPage({super.key, required this.bookingId});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isVerifying = false;
  String? _errorText;

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;
    final otpInput = _otpController.text.trim();
    if (otpInput.isEmpty) {
      setState(() => _errorText = 'Enter the 4-digit OTP received from the customer.');
      return;
    }
    if (otpInput.length != 4) {
      setState(() => _errorText = 'OTP must be exactly 4 digits.');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final doc = await _firestore.collection('bookings').doc(widget.bookingId).get();
      if (!doc.exists) {
        setState(() => _errorText = 'Booking not found.');
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final bookingWorkerId = data['workerId']?.toString();
      final status = data['status']?.toString() ?? 'pending';
      final otp = data['otp'];

      // Handle both string and number types for OTP
      final storedOtp = otp?.toString() ?? '';

      if (bookingWorkerId != user.uid) {
        setState(() => _errorText = 'You are not authorized to verify this booking.');
        return;
      }

      if (status != 'accepted') {
        setState(() => _errorText = 'OTP can only be verified after the booking is accepted.');
        return;
      }

      if (otpInput != storedOtp) {
debugPrint('OTP mismatch: input="$otpInput" (length: ${otpInput.length}), stored="$storedOtp" (length: ${storedOtp.length}, type: ${otp.runtimeType})');
        setState(() => _errorText = 'Incorrect OTP. Please check with the customer and try again.');
        return;
      }

      await _firestore.collection('bookings').doc(widget.bookingId).update({
        'status': 'in_progress',
        'otpVerified': true,
        'serviceStartedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service started successfully.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorText = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the service OTP provided by the customer to confirm the start of work.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'OTP',
                hintText: '1234',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyOtp,
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify OTP and Start Service', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
