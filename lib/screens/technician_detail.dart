import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_page.dart';
import 'chat_page.dart';

class FeedbackDialog extends StatefulWidget {
  final String workerId;

  const FeedbackDialog({super.key, required this.workerId});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();

  Future<void> _submitFeedback() async {
    if (mounted) Navigator.of(context).pop(); // Close dialog first
    await FirebaseFirestore.instance.collection('users').doc(widget.workerId).update({
      'ratings': FieldValue.arrayUnion([_rating]),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted! Thank you! ⭐')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Leave Feedback'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Rating: ${_rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Slider(
            value: _rating,
            min: 1.0,
            max: 5.0,
            divisions: 4,
            onChanged: (value) => setState(() => _rating = value),
          ),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Optional comment...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitFeedback,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class TechnicianDetailScreen extends StatelessWidget {
  final String workerId;

  const TechnicianDetailScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Details'),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(workerId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Technician not found'));
          }

          final worker = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = worker['name'] ?? 'Unknown';
          final service = worker['service'] ?? 'N/A';
          final experience = worker['experience']?.toString() ?? '0';
          final pincode = worker['pincode'] ?? 'N/A';
          final address = worker['address'] ?? 'N/A';
          final photoUrl = worker['photoUrl'] ?? '';
          final skills = List<String>.from(worker['skills'] ?? []);
          final charges = worker['charges']?.toString() ?? 'Negotiable';
          final ratings = List<dynamic>.from(worker['ratings'] ?? []);
          final avgRating = ratings.isNotEmpty 
              ? ratings.map<double>((r) => (r as num).toDouble()).reduce((a, b) => a + b) / ratings.length 
              : 4.5;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.green.shade100,
                        backgroundImage: photoUrl.isNotEmpty 
                          ? NetworkImage(photoUrl) 
                          : null,
                        child: photoUrl.isEmpty 
                          ? const Icon(Icons.engineering, size: 60, color: Colors.green)
                          : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(5, (i) => Icon(
                            i < avgRating.floor() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          )),
                          Text(' ${avgRating.toStringAsFixed(1)} (${ratings.length} reviews)'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Service & Experience
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(service, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.work, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('$experience years experience'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Skills
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Skills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills.map((skill) => Chip(
                            label: Text(skill),
                            backgroundColor: Colors.green.shade50,
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Charges
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Charges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(charges, style: const TextStyle(fontSize: 16, color: Colors.green)),
                          ],
                        ),
                        const Icon(Icons.attach_money, color: Colors.green, size: 30),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Location
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: Text(pincode),
                    subtitle: Text(address),
                  ),
                ),
                const SizedBox(height: 16),

                // Reviews (mock)
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.reviews, color: Colors.orange),
                    title: Text('${ratings.length} Reviews'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ratings.isEmpty 
                          ? const Text('No reviews yet. Be the first!')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ratings.length > 3 ? 3 : ratings.length,
                              itemBuilder: (context, index) {
                                final rating = ratings[index];
                                return ListTile(
                                  leading: const Icon(Icons.star, color: Colors.amber),
                                  title: Text('Rating: ${rating.toString()}'),
                                  subtitle: Text('User ${(index + 1).toString()} • 2 days ago'),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingPage(
                                workerId: workerId,
                                workerName: name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Book Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                otherId: workerId,
                                otherName: name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Feedback Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Leave a Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => FeedbackDialog(workerId: workerId),
                            );
                          },
                          icon: const Icon(Icons.star_rate, color: Colors.amber),
                          label: const Text('Rate this Technician'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
