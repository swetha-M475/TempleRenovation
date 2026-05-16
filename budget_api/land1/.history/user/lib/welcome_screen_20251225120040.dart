// Add this inside the Row of your _header() widget, replacing the IconButton(menu) part
Row(
  children: [
    _notificationIcon(), // New Notification Bell
    const SizedBox(width: 8),
    IconButton(
      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF5D4037).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.menu, color: Color(0xFF5D4037)),
      ),
    ),
  ],
),

// Add this helper method inside _WelcomeScreenState
Widget _notificationIcon() {
  return StreamBuilder<QuerySnapshot>(
    // Assumes a 'notifications' collection where 'userId' matches current user
    stream: _firestore
        .collection('notifications')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .where('isRead', isEqualTo: false)
        .snapshots(),
    builder: (context, snapshot) {
      int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

      return Stack(
        children: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: Color(0xFF5D4037), size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
          ),
          if (count > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    },
  );
}