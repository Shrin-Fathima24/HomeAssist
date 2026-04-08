import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'otp_verification.dart';

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
  final _chargesController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;
  bool _showBookings = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = false;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
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
        'updatedAt': Timestamp.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated! ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to access your dashboard')),
      );
    }
    
    final uid = user.uid;
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
              child: !_isEditMode ? Column(
                    children: <Widget>[
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                  // Profile Summary
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
                        if (data['verified'] ?? false)
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
                  Text(data['service'] ?? 'N/A', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatListPage()),
                        );
                      },
                      icon: const Icon(Icons.chat, size: 24),
                      label: const Text('My Chats', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Toggle bookings view
                        setState(() {
                          _showBookings = !_showBookings;
                        });
                      },
                      icon: Icon(_showBookings ? Icons.close : Icons.calendar_today, size: 24),
                      label: Text(_showBookings ? 'Hide Bookings' : 'My Bookings', style: const TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_showBookings) _buildBookingsSection(),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                ]
                )
                : Column(
                    children: <Widget>[
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
            // Skills - Multi-select chips or text field
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () {
                  _saveProfile();
                  setState(() => _isEditMode = false);
                },
                icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
                label: const Text('Save Profile', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _isEditMode = false),
                child: const Text('Cancel'),
              ),
            ),
                  ]
                ),
          );
        },
      ),
    );
  }


  Widget _buildBookingsSection() {
    final uid = _auth.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bookings')
          .where('workerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Error loading bookings: ${snapshot.error}\nPlease check your connection and try again.')),
          );
        }
        final bookings = snapshot.data?.docs ?? [];
        if (bookings.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No bookings yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Bookings will appear here when customers book your services', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        return Column(
          children: bookings.map((doc) {
            final booking = doc.data() as Map<String, dynamic>;
            final status = booking['status'] ?? 'pending';
            final userName = booking['userName'] ?? 'Unknown';
            final dateStr = booking['date'] ?? '';
            final time = booking['time'] ?? '';
            final problem = booking['problemDescription'] ?? '';

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

            Color statusColor;
            String statusText;
            switch (status) {
              case 'accepted':
                statusColor = Colors.green;
                statusText = 'Accepted';
                break;
              case 'in_progress':
                statusColor = Colors.blue;
                statusText = 'In Progress';
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusText = 'Rejected';
                break;
              case 'completed':
                statusColor = Colors.purple;
                statusText = 'Completed';
                break;
              default:
                statusColor = Colors.orange;
                statusText = 'Pending';
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Date: $formattedDate', style: const TextStyle(color: Colors.grey)),
                    Text('Time: $time', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('Problem: $problem'),
                    if (status == 'pending') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateBookingStatus(doc.id, 'accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateBookingStatus(doc.id, 'rejected'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (status == 'accepted') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OtpVerificationPage(bookingId: doc.id),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Verify OTP & Start Service'),
                        ),
                      ),
                    ],
                    if (status == 'in_progress') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _updateBookingStatus(doc.id, 'completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mark as Completed'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking $status!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating booking: $e')),
        );
      }
    }
  }
}
