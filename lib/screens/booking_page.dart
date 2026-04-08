import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingPage extends StatefulWidget {
  final String workerId;
  final String workerName;

  const BookingPage({super.key, required this.workerId, required this.workerName});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _problemController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isBooking = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _generateOtp() {
    final random = Random();
    final otp = 1000 + random.nextInt(9000);
    return otp.toString();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _confirmBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to book a service')),
      );
      return;
    }

    setState(() => _isBooking = true);

    final userId = user.uid;
    
    // Get user name from Firestore
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userName = userDoc.exists ? (userDoc.data()?['name'] ?? 'Unknown User') : 'Unknown User';
    
    final otp = _generateOtp();
    print('Generated OTP: "$otp" (length: ${otp.length})');
    final bookingData = {
      'userId': userId,
      'userName': userName,
      'workerId': widget.workerId,
      'workerName': widget.workerName,
      'date': _selectedDate!.toIso8601String(),
      'time': '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      'problemDescription': _problemController.text.trim(),
      'status': 'pending', // pending, accepted, in_progress, completed
      'otp': otp,
      'otpVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('bookings').add(bookingData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking confirmed! 🎉 Your service OTP is $otp. Share it with the worker when they arrive.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Service'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking with ${widget.workerName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Date Selection
              const Text('Select Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _selectDate,
                child: Text(_selectedDate == null
                    ? 'Choose Date'
                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
              ),
              const SizedBox(height: 16),

              // Time Selection
              const Text('Select Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _selectTime,
                child: Text(_selectedTime == null
                    ? 'Choose Time'
                    : _selectedTime!.format(context)),
              ),
              const SizedBox(height: 16),

              // Problem Description
              const Text('Problem Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _problemController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the problem you need help with...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the problem';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isBooking ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: _isBooking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirm Booking', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
