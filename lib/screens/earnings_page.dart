import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view earnings')),
      );
    }

    final uid = user.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Earnings'),
        backgroundColor: const Color(0xFF9370DB),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('bookings')
            .where('workerId', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading earnings: ${snapshot.error}'),
            );
          }

          final completedBookings = snapshot.data?.docs ?? [];
          double totalEarnings = 0.0;

          // Calculate total earnings
          for (var doc in completedBookings) {
            final booking = doc.data() as Map<String, dynamic>;
            final amount = booking['amount'] ?? 0.0;
            if (amount is num) {
              totalEarnings += amount.toDouble();
            }
          }

          return Column(
            children: [
              // Total Earnings Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9370DB), Color(0xFFBA55D3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
color: Colors.purple.withOpacity(0.3), // Ignore deprecation for now
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Total Earnings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${totalEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${completedBookings.length} completed jobs',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Completed Jobs List
              Expanded(
                child: completedBookings.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.work_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No completed jobs yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Complete some jobs to see your earnings here',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: completedBookings.length,
                        itemBuilder: (context, index) {
                          final doc = completedBookings[index];
                          final booking = doc.data() as Map<String, dynamic>;

                          final userName = booking['userName'] ?? 'Unknown Customer';
                          final dateStr = booking['date'] ?? '';
                          final time = booking['time'] ?? '';
                          final problem = booking['problemDescription'] ?? '';
                          final amount = booking['amount'] ?? 0.0;
                          final paymentMethod = booking['paymentMethod'] ?? 'Not specified';
                          final paymentStatus = booking['paymentStatus'] ?? 'pending';
                          final completedAt = booking['completedAt'];

                          // Format date
                          String formattedDate = 'N/A';
                          if (dateStr.isNotEmpty) {
                            try {
                              final date = DateTime.parse(dateStr);
                              formattedDate = '${date.day}/${date.month}/${date.year}';
                            } catch (e) {
                              formattedDate = dateStr;
                            }
                          }

                          // Format completion date
                          String completedDateStr = '';
                          if (completedAt != null && completedAt is Timestamp) {
                            final completedDate = completedAt.toDate();
                            completedDateStr = '${completedDate.day}/${completedDate.month}/${completedDate.year} at ${completedDate.hour}:${completedDate.minute.toString().padLeft(2, '0')}';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        color: Colors.blue,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          userName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
color: Colors.green.withOpacity(0.1), // Ignore deprecation for now
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '₹${amount is num ? amount.toStringAsFixed(2) : '0.00'}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        color: Colors.grey,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Service Date: $formattedDate at $time',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Completed: $completedDateStr',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Problem: $problem',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.payment,
                                        color: Colors.purple,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Payment: $paymentMethod',
                                        style: const TextStyle(
                                          color: Colors.purple,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        paymentStatus == 'completed' ? Icons.check_circle : Icons.pending,
                                        color: paymentStatus == 'completed' ? Colors.green : Colors.orange,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Payment Status: ${paymentStatus == 'completed' ? 'Received' : 'Pending'}',
                                        style: TextStyle(
                                          color: paymentStatus == 'completed' ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}