import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _nameController = TextEditingController();
  final _serviceController = TextEditingController();
  final _experienceController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _skillsController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _chargesController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = false;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _serviceController.text = data['service'] ?? '';
      _experienceController.text = data['experience']?.toString() ?? '';
      _pincodeController.text = data['pincode'] ?? '';
      _addressController.text = data['address'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _photoUrlController.text = data['photoUrl'] ?? '';
      _skillsController.text = (data['skills'] as List? ?? []).join(', ');
      _chargesController.text = data['charges'] ?? '';
      _upiIdController.text = data['upiId'] ?? '';
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final uid = _auth.currentUser!.uid;
    try {
      await _firestore.collection('users').doc(uid).update({
        'name': _nameController.text.trim(),
        'service': _serviceController.text.trim(),
        'experience': int.tryParse(_experienceController.text) ?? 0,
        'pincode': _pincodeController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'photoUrl': _photoUrlController.text.trim(),
        'skills': _skillsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'charges': _chargesController.text.trim(),
        'upiId': _upiIdController.text.trim(),
        'updatedAt': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated! ✅')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.visibility : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final photoUrl = data['photoUrl'] ?? '';
          final skills = List<String>.from(data['skills'] ?? []);
          final charges = data['charges']?.toString() ?? 'N/A';
          final ratings = List<dynamic>.from(data['ratings'] ?? []);
          final avgRating = ratings.isNotEmpty 
              ? ratings.map<double>((r) => (r as num).toDouble()).reduce((a, b) => a + b) / ratings.length 
              : 0.0;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _isEditMode 
              ? Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serviceController,
                      decoration: const InputDecoration(
                        labelText: 'Service (e.g. Electrician)',
                        prefixIcon: Icon(Icons.build),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Experience (years)',
                        prefixIcon: Icon(Icons.work),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _photoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Photo URL',
                        prefixIcon: Icon(Icons.photo),
                        border: OutlineInputBorder(),
                        hintText: 'https://example.com/photo.jpg',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _skillsController,
                      decoration: const InputDecoration(
                        labelText: 'Skills (comma separated)',
                        prefixIcon: Icon(Icons.build),
                        border: OutlineInputBorder(),
                        hintText: 'Wiring, Plumbing, Painting',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _chargesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Charges (per hour)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                        hintText: '₹500',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _upiIdController,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        prefixIcon: Icon(Icons.account_balance),
                        border: OutlineInputBorder(),
                        hintText: 'yourname@paytm or phone@upi',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Profile', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // View mode - summary cards
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            backgroundColor: Colors.green.shade100,
                            child: photoUrl.isEmpty 
                              ? const Icon(Icons.engineering, size: 60, color: Colors.green)
                              : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(data['service'] ?? 'N/A', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(5, (i) => Icon(
                          i < avgRating.floor() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        )),
                        Text(' ${avgRating.toStringAsFixed(1)} (${ratings.length} reviews)'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.build, color: Colors.green, size: 28),
                                const SizedBox(width: 12),
                                Expanded(child: Text(data['service'] ?? 'N/A', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.work_outline, color: Colors.blue, size: 28),
                                const SizedBox(width: 12),
                                Text('${data['experience']?.toString() ?? '0'} years experience'),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.orange, size: 28),
                                const SizedBox(width: 12),
                                Text(data['pincode'] ?? 'N/A'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Skills', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: skills.map((skill) => Chip(
                                label: Text(skill),
                                backgroundColor: Colors.green.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              children: [
                                Text('₹$charges', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                                const Text('per hour', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('${ratings.length}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber)),
                                const Text('reviews', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isEditMode = true),
                        icon: const Icon(Icons.edit, size: 24),
                        label: const Text('Edit Profile', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _serviceController.dispose();
    _experienceController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _photoUrlController.dispose();
    _skillsController.dispose();
    _chargesController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }
}

