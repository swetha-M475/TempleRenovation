import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class FinanceTabSection extends StatefulWidget {
  final String projectId;
  final Function(String) onShowImage;

  const FinanceTabSection({
    Key? key,
    required this.projectId,
    required this.onShowImage,
  }) : super(key: key);

  @override
  State<FinanceTabSection> createState() => _FinanceTabSectionState();
}

class _FinanceTabSectionState extends State<FinanceTabSection> {
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color darkMaroonText = Color(0xFF4A1010);

  // Deep Link Logic to open UPI Apps
  Future<void> _initiateUPIDeepLink(String upiId, String amount, String title) async {
    // Standard UPI URI format
    final String upiUrl =
        "upi://pay?pa=$upiId&pn=TempleProject&am=$amount&cu=INR&tn=${Uri.encodeComponent("Payment for $title")}";
    final Uri uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar("No UPI app found on this device.");
      }
    } catch (e) {
      _showErrorSnackBar("Could not launch payment app.");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showPaymentOptions(String docId, String upiId, String amount, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Choose Payment App",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              _buildAppTile("Google Pay", Icons.account_balance, Colors.blue, upiId, amount, title, docId),
              _buildAppTile("PhonePe", Icons.account_balance_wallet, Colors.purple, upiId, amount, title, docId),
              _buildAppTile("Paytm", Icons.payments, Colors.lightBlue, upiId, amount, title, docId),
              _buildAppTile("Other UPI App", Icons.qr_code, Colors.grey, upiId, amount, title, docId),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppTile(String name, IconData icon, Color color, String upiId,
      String amount, String title, String docId) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
      title: Text(name),
      onTap: () async {
        Navigator.pop(context);
        await _initiateUPIDeepLink(upiId, amount, title);
        _askIfPaid(docId);
      },
    );
  }

  void _askIfPaid(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: const Text("If you completed the payment in the UPI app, click 'Mark as Paid'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              FirebaseFirestore.instance.collection('transactions').doc(docId).update({
                'status': 'paid',
                'paidAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text("Mark as Paid", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Order by status descending (pending starts with 'p', paid with 'p' - 
      // usually better to use a timestamp for logic if statuses are mixed)
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('projectId', isEqualTo: widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Sorting Logic: Pending first, then latest Paid
        var docs = snapshot.data!.docs;
        docs.sort((a, b) {
          String statusA = a.data()['status'] ?? 'pending';
          String statusB = b.data()['status'] ?? 'pending';

          if (statusA == 'pending' && statusB != 'pending') return -1;
          if (statusA != 'pending' && statusB == 'pending') return 1;

          // If both same status, sort by created date (latest first)
          Timestamp tA = a.data()['createdAt'] ?? Timestamp.now();
          Timestamp tB = b.data()['createdAt'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) return const Center(child: Text("No fund requests found."));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final docId = docs[i].id;
            final status = data['status'] ?? 'pending';
            final upiId = data['upiId'] ?? '';
            final amount = (data['amount'] ?? '0').toString();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(data['title'] ?? 'Request',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: darkMaroonText)),
                subtitle: Text('₹$amount • ${status.toUpperCase()}',
                    style: TextStyle(
                        color: status == 'paid' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UPI ID: $upiId', style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 10),
                        if (data['qrUrl'] != null) ...[
                          GestureDetector(
                            onTap: () => widget.onShowImage(data['qrUrl']),
                            child: Image.network(data['qrUrl'], height: 150),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (status == 'pending')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.send, color: Colors.white),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  onPressed: () => _showPaymentOptions(docId, upiId, amount, data['title'] ?? 'Request'),
                                  label: const Text('PAY NOW', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => FirebaseFirestore.instance.collection('transactions').doc(docId).update({'status': 'rejected'}),
                                  child: const Text('Reject', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}