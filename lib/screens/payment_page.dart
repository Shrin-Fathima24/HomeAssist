import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentPage extends StatefulWidget {
  final String bookingId;
  final String workerId;
  final String workerName;
  final double amount;

  const PaymentPage({
    super.key,
    required this.bookingId,
    required this.workerId,
    required this.workerName,
    required this.amount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedMethod = 'UPI';
  bool _isProcessing = false;
  bool _loadingUpi = true;
  String? _upiId;
  String? _upiError;

  @override
  void initState() {
    super.initState();
    _loadWorkerUpiId();
  }

  Future<void> _loadWorkerUpiId() async {
    try {
      final workerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.workerId).get();
      final workerData = workerDoc.data();
      setState(() {
        _upiId = workerData?['upiId'] as String?;
        _loadingUpi = false;
      });
    } catch (e) {
      setState(() {
        _upiError = 'Unable to load worker UPI details.';
        _loadingUpi = false;
      });
    }
  }

  Future<void> _completePayment() async {
    if (_selectedMethod == 'UPI') {
      await _launchUpiPayment();
      return;
    }
    // Cash payment
    await _updatePayment('completed', 'Cash');
  }

  Future<void> _launchUpiPayment() async {
    if (_upiId == null || _upiId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker UPI ID is not available. Please ask them to add their UPI ID.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Build UPI URL - simpler format that works with all UPI apps
      final upiUrl = 'upi://pay?pa=${_upiId!}&pn=${widget.workerName.replaceAll(' ', '%20')}&am=${widget.amount.toStringAsFixed(2)}&tn=Service%20Payment&cu=INR';
      
      final uri = Uri.parse(upiUrl);

      if (!await canLaunchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI app found. Please install Google Pay, PhonePe, or Paytm.')),
        );
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Payment Done?'),
          content: const Text('Did you successfully complete the UPI payment?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not Yet')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes, Completed')),
          ],
        ),
      );

      if (confirmed == true) {
        await _updatePayment('completed', 'UPI');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updatePayment(String paymentStatus, String method) async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
        'paymentStatus': paymentStatus,
        'paymentMethod': method,
        'actualPaymentMethod': method,
        'paymentCompletedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment via $method marked complete! ✅')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₹${widget.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Technician: ${widget.workerName}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 28),
            const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Online (UPI)'),
                subtitle: const Text('Pay immediately using your UPI app'),
leading: CircleAvatar(
                  backgroundColor: _selectedMethod == 'UPI' ? Colors.green : Colors.transparent,
                  radius: 20,
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                ),
              ),
            ),
            if (_selectedMethod == 'UPI') ...[
              const SizedBox(height: 12),
              _buildUpiDetails(),
            ],
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text('Cash'),
                subtitle: const Text('Pay the technician in cash'),
leading: CircleAvatar(
                  backgroundColor: _selectedMethod == 'Cash' ? Colors.orange : Colors.transparent,
                  radius: 20,
                  child: const Icon(Icons.payment, color: Colors.white, size: 20),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _completePayment,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_selectedMethod == 'UPI' ? 'Pay via UPI' : 'Complete Cash Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiDetails() {
    if (_loadingUpi) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_upiError != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_upiError!, style: const TextStyle(color: Colors.red)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text('UPI ID', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(_upiId ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('You will be redirected to your UPI app', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
