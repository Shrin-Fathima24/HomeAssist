import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../login.dart'; // For logout
import '../screens/technician_detail.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _pincodeFilter = '';

  final List<String> categories = [
    'All', 'Electrician ⚡', 'Plumber 🚿', 'Painter 🎨', 'Carpenter 🔨', 'Mechanic 🛠️'
  ];

  @override
  Widget build(BuildContext context) {
    final query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('verified', isEqualTo: true)
        .where('service', isNotEqualTo: null)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Technician'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search technicians...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter Pincode',
                          prefixIcon: const Icon(Icons.location_on),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.filter_list),
                            onPressed: () {
                              setState(() {
                                _pincodeFilter = _pincodeController.text;
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final selected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: selected,
                          onSelected: (sel) => setState(() => _selectedCategory = cat),
                          selectedColor: Colors.purple.shade100,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Workers List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final workers = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final service = data['service']?.toString() ?? '';
                  final pincode = data['pincode']?.toString() ?? '';
                  final name = data['name']?.toString().toLowerCase() ?? '';
                  final searchQuery = _searchController.text.toLowerCase();
                  final matchesSearch = name.contains(searchQuery) || service.contains(searchQuery);
                  final matchesCategory = _selectedCategory == 'All' || service.contains(_selectedCategory.replaceAll(RegExp(r' [⚡🚿🎨🔨🛠️]'), ''));
                  final matchesPincode = _pincodeFilter.isEmpty || pincode.contains(_pincodeFilter);
                  return matchesSearch && matchesCategory && matchesPincode;
                }).toList();
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: workers.length,
                  itemBuilder: (context, index) {
                    final worker = workers[index].data() as Map<String, dynamic>;
                    return WorkerCard(worker: worker, workerId: workers[index].id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerCard extends StatelessWidget {
  final Map<String, dynamic> worker;
  final String workerId;

  const WorkerCard({super.key, required this.worker, required this.workerId});

  String _calculateDistance(String workerPincode, String userPincode) {
    if (workerPincode.isEmpty || userPincode.isEmpty) return 'N/A';
    final workerNum = int.tryParse(workerPincode) ?? 0;
    final userNum = int.tryParse(userPincode) ?? 0;
    return '${(workerNum - userNum).abs()} km';
  }

  @override
  Widget build(BuildContext context) {
    final name = worker['name'] ?? 'Unknown';
    final service = worker['service'] ?? 'N/A';
    final experience = worker['experience']?.toString() ?? '0';
    final pincode = worker['pincode'] ?? 'N/A';
    final address = worker['address'] ?? 'N/A';
    final ratings = worker['ratings'] as List<dynamic>? ?? [];
    final avgRating = ratings.isNotEmpty ? ratings.map<double>((r) => (r as num).toDouble()).reduce((a, b) => a + b) / ratings.length : 4.5;

    // Mock user pincode - replace with actual user profile
    const userPincode = '560001'; 

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.engineering, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(service, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      if (worker['charges'] != null) Text('₹${worker['charges']}/hr', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text('${avgRating.toStringAsFixed(1)} (${ratings.length} reviews)'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_calculateDistance(pincode, userPincode)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Experience: $experience years'),
            Text('Pincode: $pincode'),
            Text('Address: $address', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            if (worker['skills'] != null && (worker['skills'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  children: (worker['skills'] as List).take(3).map<Widget>((skill) => Chip(
                    label: Text(skill.toString(), style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.green.shade100,
                  )).toList(),
                ),
              ),

            const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TechnicianDetailScreen(workerId: workerId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('View Details'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
