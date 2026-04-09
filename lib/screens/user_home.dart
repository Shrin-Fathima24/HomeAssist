import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/technician_detail.dart';
import 'ratings_page.dart';
import 'payment_page.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _pincodeFilter = '';
  int _bookingTabIndex = 0;

  final List<String> categories = [
    'All', 'Electrician ⚡', 'Plumber 🚿', 'Painter 🎨', 'Carpenter 🔨', 'Mechanic 🛠️'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pincodeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to access your dashboard')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeAssist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: 'My Ratings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RatingsPage()),
              );
            },
          ),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Find Technician'),
            Tab(text: 'My Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFindTechnicianTab(),
          _buildMyBookingsTab(),
        ],
      ),
    );
  }

  Widget _buildFindTechnicianTab() {
    final query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('verified', isEqualTo: true)
        .snapshots();

    return Column(
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
                final verified = data['verified'] ?? false;
                final searchQuery = _searchController.text.toLowerCase();
                final hasService = service.isNotEmpty;
                final isVerified = verified == true;
                final matchesSearch = searchQuery.isEmpty || name.contains(searchQuery) || service.toLowerCase().contains(searchQuery);
                final categoryName = _selectedCategory.split(' ')[0]; // Remove emoji
                final matchesCategory = _selectedCategory == 'All' || service.toLowerCase().contains(categoryName.toLowerCase());
                final matchesPincode = _pincodeFilter.isEmpty || pincode.contains(_pincodeFilter);
                return hasService && isVerified && matchesSearch && matchesCategory && matchesPincode;
              }).toList();
              
              if (workers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No technicians found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Try adjusting your filters or check back later', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
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
    );
  }

  Widget _buildMyBookingsTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please login to view bookings.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('bookings').where('userId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading bookings: ${snapshot.error}\nPlease check your connection and try again.'),
          );
        }

        final bookings = snapshot.data?.docs ?? [];
        final currentBookings = bookings.where((doc) {
          final status = (doc.data() as Map<String, dynamic>)['status']?.toString() ?? 'pending';
          return status == 'pending' || status == 'accepted' || status == 'in_progress';
        }).toList();
        final pastBookings = bookings.where((doc) {
          final status = (doc.data() as Map<String, dynamic>)['status']?.toString() ?? 'pending';
          return status == 'completed' || status == 'paid' || status == 'rejected';
        }).toList();
        final selectedBookings = _bookingTabIndex == 0 ? currentBookings : pastBookings;

        if (bookings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No bookings yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                SizedBox(height: 8),
                Text('Book a service to get started!', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (selectedBookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_bookingTabIndex == 0 ? Icons.schedule : Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _bookingTabIndex == 0 ? 'No current bookings' : 'No past bookings',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  _bookingTabIndex == 0 ? 'Your upcoming bookings will appear here.' : 'Completed or rejected bookings will appear here.',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Current bookings'),
                      selected: _bookingTabIndex == 0,
                      onSelected: (_) => setState(() => _bookingTabIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Past bookings'),
                      selected: _bookingTabIndex == 1,
                      onSelected: (_) => setState(() => _bookingTabIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: selectedBookings.length,
                itemBuilder: (context, index) {
                  final bookingDoc = selectedBookings[index];
                  final booking = bookingDoc.data() as Map<String, dynamic>;
                  final status = booking['status']?.toString() ?? 'pending';
                  final workerName = booking['workerName']?.toString() ?? 'Unknown';
                  final dateStr = booking['date']?.toString() ?? '';
                  final time = booking['time']?.toString() ?? '';
                  final problem = booking['problemDescription']?.toString() ?? '';

                  String formattedDate = 'N/A';
                  if (dateStr.isNotEmpty) {
                    try {
                      final date = DateTime.parse(dateStr);
                      formattedDate = '${date.day}/${date.month}/${date.year}';
                    } catch (_) {
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
                      statusColor = Colors.blueAccent;
                      statusText = 'In Progress';
                      break;
                    case 'rejected':
                      statusColor = Colors.red;
                      statusText = 'Rejected';
                      break;
                    case 'completed':
                      statusColor = Colors.blue;
                      statusText = 'Completed';
                      break;
                    case 'paid':
                      statusColor = Colors.green;
                      statusText = 'Paid';
                      break;
                    default:
                      statusColor = Colors.orange;
                      statusText = 'Pending';
                  }

                  final amount = booking['amount'];
                  final paymentMethod = booking['paymentMethod']?.toString();
                  final paymentStatus = booking['paymentStatus']?.toString() ?? 'pending';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(workerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha((255 * 0.1).round()),
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
                          if (status == 'accepted' || status == 'in_progress') ...[
                            const SizedBox(height: 8),
                            Text("Service OTP: ${booking['otp'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                          if (status == 'completed' && amount != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Payment Details',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Total Amount: ₹${amount is num ? amount.toStringAsFixed(2) : amount.toString()}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if (paymentMethod != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Payment Method: $paymentMethod',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  if (paymentStatus == 'pending' && paymentMethod == 'Online') ...[
                                    const Text(
                                      'Please complete the UPI payment to finalize the service.',
                                      style: TextStyle(color: Colors.red, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PaymentPage(
                                                bookingId: bookingDoc.id,
                                                workerId: booking['workerId'],
                                                workerName: workerName,
                                                amount: amount is num ? amount.toDouble() : 0.0,
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.payment, size: 16),
                                        label: const Text('Pay via UPI'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else if (paymentStatus == 'pending' && paymentMethod == 'Cash') ...[
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pay in cash when technician arrives',
                                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: () async {
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Mark Cash Payment Complete'),
                                                  content: Text('Did you pay ₹${amount is num ? amount.toStringAsFixed(2) : amount.toString()} in cash to $workerName?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
                                                    ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
                                                  ],
                                                ),
                                              );

                                              if (confirmed == true && mounted) {
                                                try {
                                                  await _firestore.collection('bookings').doc(bookingDoc.id).update({
                                                    'paymentStatus': 'completed',
                                                    'paymentCompletedAt': FieldValue.serverTimestamp(),
                                                    'actualPaymentMethod': 'Cash',
                                                  });

                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Payment marked complete! ✅')),
                                                  );
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            child: const Text('Mark as Paid'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (paymentStatus == 'completed') ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Payment Completed',
                                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
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
    final photoUrl = worker['photoUrl'] ?? '';
    final charges = worker['charges']?.toString() ?? 'Negotiable';
    final skills = worker['skills'] as List<dynamic>? ?? [];
    final ratings = worker['ratings'] as List<dynamic>? ?? [];
    final avgRating = ratings.isNotEmpty ? ratings.map<double>((r) => (r as num).toDouble()).reduce((a, b) => a + b) / ratings.length : 0.0;
    final verified = worker['verified'] ?? false;

    // Mock user pincode - replace with actual user profile
    const userPincode = '560001';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.green.shade100,
                      child: photoUrl.isEmpty ? const Icon(Icons.engineering, color: Colors.white) : null,
                    ),
                    if (verified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          if (verified)
                            const Icon(Icons.verified, color: Colors.green, size: 18),
                        ],
                      ),
                      Text(service, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      Text('₹$charges/hr', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(' ${avgRating.toStringAsFixed(1)} (${ratings.length})'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Experience: $experience years', style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_calculateDistance(pincode, userPincode), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('📍 $pincode', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (address.isNotEmpty) Text('🏠 $address', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (skills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: skills.take(3).map<Widget>((skill) => Chip(
                    label: Text(skill.toString(), style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green.shade100,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
