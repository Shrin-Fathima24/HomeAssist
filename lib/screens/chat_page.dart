import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String otherId;
  final String otherName;

  const ChatPage({super.key, required this.otherId, required this.otherName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  String get _currentUserId => _auth.currentUser?.uid ?? 'unknown_user';
  String get _currentUserName => _auth.currentUser?.displayName ?? _auth.currentUser?.email?.split('@').first ?? 'You';

  String get _chatId {
    final ids = [_currentUserId, widget.otherId]..sort();
    return ids.join('_');
  }

  Future<void> _sendMessage({required String type, String? content}) async {
    if (_isSending) return;
    if (type == 'text' && (content == null || content.trim().isEmpty)) return;

    setState(() => _isSending = true);

    final messageData = {
      'senderId': _currentUserId,
      'senderName': _currentUserName,
      'type': type,
      'content': content ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final chatDoc = _firestore.collection('chats').doc(_chatId);
      await chatDoc.set({
        'members': [_currentUserId, widget.otherId],
        'participantNames': {
          _currentUserId: _currentUserName,
          widget.otherId: widget.otherName,
        },
        'lastMessage': type == 'text'
            ? content
            : type == 'image'
                ? '📷 Image'
                : type == 'video'
                    ? '🎥 Video'
                    : '⚠ Fault report',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await chatDoc.collection('messages').add(messageData);
      if (type == 'text') {
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendFaultExplanation() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Describe the fault'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Share what is wrong and what you observed...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Send Fault'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _sendMessage(type: 'fault', content: result);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected')),
          );
        }
        return;
      }
      await _uploadMedia(picked, 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No video selected')),
          );
        }
        return;
      }
      await _uploadMedia(picked, 'video');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    }
  }

  Future<void> _uploadMedia(XFile file, String type) async {
    setState(() => _isSending = true);
    try {
      final storagePath = 'chat_media/$_chatId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final uploadTask = _storage.ref(storagePath).putFile(File(file.path));
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      await _sendMessage(type: type, content: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Stream<QuerySnapshot> get _messageStream {
    return _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['senderId'] == _currentUserId;
    final bgColor = isMine ? Colors.purple.shade100 : Colors.grey.shade200;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 0),
      bottomRight: Radius.circular(isMine ? 0 : 16),
    );

    final type = message['type'] as String? ?? 'text';
    final content = message['content']?.toString() ?? '';
    Widget body;

    if (type == 'image') {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          content,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            width: 220,
            height: 220,
            child: Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
          ),
        ),
      );
    } else if (type == 'video') {
      body = SizedBox(
        width: 220,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, size: 36, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text('Video sent', style: TextStyle(color: Colors.blue.shade700))),
          ],
        ),
      );
    } else if (type == 'fault') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fault report', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(content),
        ],
      );
    } else {
      body = Text(content, style: const TextStyle(fontSize: 16));
    }

    return Column(
      crossAxisAlignment: align,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
            ),
            padding: const EdgeInsets.all(12),
            child: body,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: isMine ? 0 : 16, right: isMine ? 16 : 0, bottom: 4),
          child: Text(
            message['senderName']?.toString() ?? '',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherName),
            const SizedBox(height: 2),
            const Text('Chat', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF9370DB),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Chat load failed: ${snapshot.error}'));
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Start the conversation by sending a message or sharing the fault details.'),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo, color: Colors.green),
                      tooltip: 'Send image',
                    ),
                    IconButton(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam, color: Colors.blue),
                      tooltip: 'Send video',
                    ),
                    IconButton(
                      onPressed: _sendFaultExplanation,
                      icon: const Icon(Icons.report_problem, color: Colors.red),
                      tooltip: 'Share fault details',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Color(0xFFF3F2F7),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF9370DB),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isSending ? null : () => _sendMessage(type: 'text', content: _messageController.text),
                      ),
                    ),
                  ],
                ),
                if (_isSending)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Chats')),
        body: const Center(child: Text('Please login to view chats.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Chats'),
        backgroundColor: const Color(0xFF9370DB),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('members', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load chats: ${snapshot.error}'));
          }

          final chats = snapshot.data?.docs.toList() ?? [];
          chats.sort((a, b) {
            final aTime = (a['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (b['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          if (chats.isEmpty) {
            return const Center(child: Text('No chats yet. You will see conversations here once a user contacts you.'));
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final members = List<String>.from(chat['members'] ?? []);
              final names = Map<String, dynamic>.from(chat['participantNames'] ?? {});
              final peerId = members.firstWhere((id) => id != uid, orElse: () => uid);
              final peerName = names[peerId]?.toString() ?? 'Chat';
              final lastMessage = chat['lastMessage']?.toString() ?? 'No messages yet';
              final updatedAt = (chat['updatedAt'] as Timestamp?)?.toDate();

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(peerName),
                subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: updatedAt == null ? null : Text('${updatedAt.hour}:${updatedAt.minute.toString().padLeft(2, '0')}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(otherId: peerId, otherName: peerName),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
