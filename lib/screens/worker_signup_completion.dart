import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class WorkerSignupCompletionPage extends StatefulWidget {
  const WorkerSignupCompletionPage({super.key});

  @override
  State<WorkerSignupCompletionPage> createState() => _WorkerSignupCompletionPageState();
}

class _WorkerSignupCompletionPageState extends State<WorkerSignupCompletionPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _serviceController = TextEditingController();
  final _experienceController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();

  // State
  int _currentStep = 0;
  List<String> _selectedSkills = [];
  Map<String, String> _documents = {}; // {'id_proof': url, 'certificate': url}
  List<String> _certificateUrls = [];
  String _videoUrl = '';
  String _resumeUrl = '';
  bool _isLoading = false;

  // Predefined skills
  final List<String> _availableSkills = [
    'Electrician', 'Plumber', 'Carpenter', 'Painter', 'AC Technician',
    'Mason', 'Welder', 'Tiler', 'Roofer', 'HVAC Technician',
    'Locksmith', 'Pest Control', 'Cleaner', 'Gardener', 'Driver'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _serviceController.text = data['service'] ?? '';
      _experienceController.text = data['experience']?.toString() ?? '';
      _pincodeController.text = data['pincode'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _selectedSkills = List<String>.from(data['skills'] ?? []);
      _documents = Map<String, String>.from(data['documents'] ?? {});
      final uploads = Map<String, dynamic>.from(data['uploads'] ?? {});
      _resumeUrl = uploads['resume']?.toString() ?? '';
      _videoUrl = uploads['video']?.toString() ?? '';
      _certificateUrls = List<String>.from(uploads['certificates'] ?? const []);
    }
  }

  Future<void> _uploadDocument(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      final ref = _storage.ref().child('worker_documents/$uid/$type/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final bytes = await image.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      setState(() {
        _documents[type] = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type uploaded!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _completeSignup() async {
    if (_currentStep != 2) return;

    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      await _firestore.collection('users').doc(uid).update({
        'service': _serviceController.text.trim(),
        'experience': int.tryParse(_experienceController.text) ?? 0,
        'pincode': _pincodeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'skills': _selectedSkills,
        'documents': _documents,
        'uploads': {
          ..._documents,
          'video': _videoUrl,
          'resume': _resumeUrl,
          'certificates': _certificateUrls,
        },
        'status': 'pending',
        'verified': false,
        'profileComplete': true,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for admin approval! ⏳')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Worker Profile')),
      body: Column(
        children: [
          // Step indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(3, (index) => Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: index <= _currentStep 
                        ? Colors.green 
                        : Colors.grey,
                      child: Text('${index + 1}'),
                    ),
                    Text(['Basic', 'Skills', 'Documents'][index]),
                  ],
                ),
              )),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: FloatingActionButton(
                heroTag: 'prev',
                onPressed: () => setState(() => _currentStep--),
                child: const Icon(Icons.arrow_back),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'next',
            onPressed: _isLoading ? null : () {
              if (_validateCurrentStep()) {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  _completeSignup();
                }
              }
            },
            label: Text(_currentStep < 2 ? 'Next' : 'Complete'),
            icon: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return Column(
          children: [
            TextField(
              controller: _serviceController,
              decoration: const InputDecoration(
                labelText: 'Service Type',
                prefixIcon: Icon(Icons.build),
              ),
            ),
            TextField(
              controller: _experienceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Experience (years)',
                prefixIcon: Icon(Icons.work),
              ),
            ),
            TextField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pincode',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            const Text('Select your skills:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSkills.map((skill) => FilterChip(
                label: Text(skill),
                selected: _selectedSkills.contains(skill),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSkills.add(skill);
                    } else {
                      _selectedSkills.remove(skill);
                    }
                  });
                },
              )).toList(),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            const Text('Upload Documents:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDocumentButton('ID Proof (Aadhaar)', 'id_proof'),
            const ListTile(
              title: Text('Certificates (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            _buildCertificateButton(),
            if (_certificateUrls.isNotEmpty)
              ..._certificateUrls.map(
                (url) => ListTile(
                  leading: const Icon(Icons.workspace_premium),
                  title: const Text('Certificate'),
                  subtitle: Text(url),
                ),
              ),
            const Divider(),
            const ListTile(title: Text('Video/Work Demo', style: TextStyle(fontWeight: FontWeight.bold))),
            _buildVideoButton(),
            const SizedBox(height: 8),
            const ListTile(title: Text('Resume', style: TextStyle(fontWeight: FontWeight.bold))),
            _buildResumeButton(),
            const SizedBox(height: 16),
            Text('Required uploads: ${_documents.containsKey('id_proof') ? 1 : 0}/1 + Resume', style: Theme.of(context).textTheme.titleMedium),
            if (_documents.isNotEmpty) ...[
              ..._documents.entries.map((e) => ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text(e.key.replaceAll('_', ' ').toUpperCase()),
                subtitle: Text(e.value),
              )),
            ],
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildDocumentButton(String label, String type) {
    return ListTile(
      leading: const Icon(Icons.upload_file),
      title: Text(label),
      trailing: ElevatedButton(
        onPressed: () => _uploadDocument(type),
        child: const Text('Upload'),
      ),
      subtitle: _documents.containsKey(type) ? Text('Uploaded') : null,
    );
  }

  Widget _buildVideoButton() => ListTile(
    leading: const Icon(Icons.video_library),
    title: const Text('Upload Work Video'),
    trailing: ElevatedButton(
      onPressed: _isLoading ? null : _uploadVideo,
      child: Text(_videoUrl.isNotEmpty ? 'Uploaded' : 'Upload'),
    ),
  );

  Widget _buildCertificateButton() => ListTile(
    leading: const Icon(Icons.workspace_premium),
    title: const Text('Upload Certificates (PDF/JPG)'),
    trailing: ElevatedButton(
      onPressed: _isLoading ? null : _uploadCertificates,
      child: const Text('Upload'),
    ),
  );

  Widget _buildResumeButton() => ListTile(
    leading: const Icon(Icons.picture_as_pdf),
    title: const Text('Upload Resume'),
    trailing: ElevatedButton(
      onPressed: _isLoading ? null : _uploadResume,
      child: Text(_resumeUrl.isNotEmpty ? 'Uploaded' : 'Upload'),
    ),
  );

  Future<void> _uploadVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    final bytes = await video.readAsBytes();
    final ext = video.path.contains('.') ? video.path.split('.').last : 'mp4';
    await _uploadBytes(bytes, 'video', ext);
  }

Future<void> _uploadResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.bytes == null) return;
    await _uploadBytes(picked.bytes!, 'resume', picked.extension ?? 'pdf');
  }

  Future<void> _uploadCertificates() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.bytes == null) continue;
      final certUrl = await _uploadBytes(
        file.bytes!,
        'certificate',
        file.extension ?? 'pdf',
        nestedFolder: 'certificates',
      );
      if (certUrl != null) {
        setState(() => _certificateUrls.add(certUrl));
      }
    }
  }

  Future<String?> _uploadBytes(Uint8List bytes, String type, String extension, {String? nestedFolder}) async {
    setState(() => _isLoading = true);
    try {
      final uid = _auth.currentUser!.uid;
      final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
      final folder = nestedFolder ?? type;
      final ref = _storage.ref().child('worker_uploads/$uid/$folder/${DateTime.now().millisecondsSinceEpoch}.$cleanExt');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();
      if (type == 'video') setState(() => _videoUrl = url);
      if (type == 'resume') setState(() => _resumeUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type uploaded')));
      return url;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      return null;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _serviceController.text.isNotEmpty &&
               _experienceController.text.isNotEmpty &&
               _pincodeController.text.isNotEmpty &&
               _phoneController.text.isNotEmpty;
      case 1:
        return _selectedSkills.isNotEmpty;
      case 2:
        return _documents.containsKey('id_proof') && _resumeUrl.isNotEmpty;
      default:
        return true;
    }
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _experienceController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

