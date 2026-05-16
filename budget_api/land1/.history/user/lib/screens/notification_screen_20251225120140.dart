class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFDF5),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5D4037)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'NOTIFICATIONS',
          style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No notifications from admin', style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;

              return Card(
                color: isRead ? Colors.white : const Color(0xFFF5E6CA).withOpacity(0.3),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () {
                    // Mark as read when clicked
                    firestore.collection('notifications').doc(docs[index].id).update({'isRead': true});
                  },
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF5D4037),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    data['title'] ?? 'Admin Message',
                    style: GoogleFonts.poppins(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                  ),
                  subtitle: Text(data['message'] ?? ''),
                  trailing: !isRead ? const CircleAvatar(radius: 4, backgroundColor: Colors.red) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}