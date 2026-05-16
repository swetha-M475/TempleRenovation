import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectChatSection extends StatefulWidget {
  final String projectId;
  final String currentRole;

  const ProjectChatSection({
    super.key,
    required this.projectId,
    required this.currentRole,
  });

  @override
  State<ProjectChatSection> createState() => _ProjectChatSectionState();
}

class _ProjectChatSectionState extends State<ProjectChatSection> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Color primaryMaroon = const Color(0xFF6A1F1A);
  final Color myBubbleColor = const Color(0xFF8E3D2C);

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await _firestore.collection('project_messages').add({
        'projectId': widget.projectId,
        'message': text,
        'senderRole': widget.currentRole,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('project_messages')
                .where('projectId', isEqualTo: widget.projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text("Error loading feedback",
                        style: GoogleFonts.poppins()));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Text("No feedback yet.",
                      style: GoogleFonts.poppins(color: Colors.grey)),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final message = data['message'] ?? '';
                  final role = data['senderRole'] ?? '';
                  final type = data['type'] ?? 'text';

                  final isMe = role == widget.currentRole;
                  final isSystem = type == 'system_completion_request';

                  return Align(
                    alignment: isSystem
                        ? Alignment.center
                        : (isMe ? Alignment.centerRight : Alignment.centerLeft),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: isSystem
                            ? Colors.blue[50]
                            : (isMe ? myBubbleColor : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: isSystem
                            ? Border.all(color: Colors.blue[200]!)
                            : null,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: const Offset(0, 1))
                        ],
                      ),
                      child: Text(
                        message,
                        textAlign:
                            isSystem ? TextAlign.center : TextAlign.start,
                        style: GoogleFonts.poppins(
                          fontSize: isSystem ? 13 : 14,
                          fontWeight:
                              isSystem ? FontWeight.bold : FontWeight.normal,
                          color: isSystem
                              ? Colors.blue[800]
                              : (isMe ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Type feedback...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: primaryMaroon,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
