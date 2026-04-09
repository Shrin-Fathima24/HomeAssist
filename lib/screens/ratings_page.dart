import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login to view ratings')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ratings & Reviews'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feedback Given', icon: Icon(Icons.rate_review)),
            Tab(text: 'Feedback Received', icon: Icon(Icons.star)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedbackGivenTab(user.uid),
          _buildFeedbackReceivedTab(user.uid),
        ],
      ),
    );
  }

  Widget _buildFeedbackGivenTab(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('feedback').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No feedback given'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final workerId = data['workerId'] as String? ?? 'Unknown Worker';
            final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
            final comment = data['comment'] as String? ?? '';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            return ListTile(
              title: Text('Worker: $workerId'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (comment.isNotEmpty) Text(comment),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: Text(rating.toStringAsFixed(1)),
            );
          },
        );
      },
    );
  }

  Widget _buildFeedbackReceivedTab(String userId) {
    return FutureBuilder<String>(
      future: _getUserRole(userId),
      builder: (context, roleSnap) {
        if (roleSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (roleSnap.hasError) {
          return Center(child: Text('Error: ${roleSnap.error}'));
        }
        if (!roleSnap.hasData || roleSnap.data != 'worker') {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Feedback received is only available for worker dashboards.\nPlease sign in as a worker to view received reviews.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('feedback').where('workerId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const Center(child: Text('No feedback'));
            double avg = 0;
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              avg += (data['rating'] as num?)?.toDouble() ?? 0.0;
            }
            avg /= docs.length;
            return ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Average rating: ${avg.toStringAsFixed(1)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${docs.length} review${docs.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
                  final comment = data['comment'] as String? ?? '';
                  final reviewerId = data['userId'] as String? ?? 'Unknown User';
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  return ListTile(
                    title: Text('Rating: ${rating.toStringAsFixed(1)} ★'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (comment.isNotEmpty) Text(comment),
                        Text('By $reviewerId • ${_formatDate(createdAt)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _getUserRole(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['role'] ?? 'user';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return date.toString();
  }
}
