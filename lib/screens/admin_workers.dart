import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminWorkersScreen extends StatelessWidget {
  const AdminWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Approvals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'worker')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading workers'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending workers'));
          }
          final workers = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString();
            final verified = data['verified'] == true;
            final profileComplete = data['profileComplete'] == true;
            return (status == null && !verified && profileComplete) || status == 'pending';
          }).toList();
          if (workers.isEmpty) {
            return const Center(child: Text('No pending workers'));
          }
          return ListView.builder(
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index].data() as Map<String, dynamic>;
              final uid = workers[index].id;
              return Card(
                child: ExpansionTile(
                  title: Text(worker['name'] ?? 'Unknown'),
                  subtitle: Text('Service: ${worker['service'] ?? 'N/A'}'),
                  children: [
                    ListTile(title: const Text('Details'), subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Experience: ${worker['experience'] ?? 0} years'),
                        Text('Pincode: ${worker['pincode'] ?? 'N/A'}'),
                        Text('Phone: ${worker['phone'] ?? 'N/A'}'),
                      ],
                    )),
                    if (worker['uploads'] != null) ...[
                      const Divider(),
                      const Text('Uploads:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...(worker['uploads'] as Map).entries.map((e) => ListTile(
                        leading: const Icon(Icons.attachment),
                        title: Text(e.key.toUpperCase()),
                        subtitle: e.value is String ? Text(e.value) : Text('Multiple files'),
                        onTap: e.value is String ? () => _launchURL(e.value) : null,
                      )),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveWorker(uid),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _rejectWorker(context, uid),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approveWorker(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'status': 'approved',
      'verified': true,
      'approvedAt': Timestamp.now(),
    });
  }

  Future<void> _rejectWorker(BuildContext context, String uid) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Reason'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Reason for rejection'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Reject')),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'rejected',
        'rejectReason': reason,
        'verified': false,
        'updatedAt': Timestamp.now(),
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

