// FULL UPDATED CODE WITH FIRESTORE LOGIC

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map<String, dynamic>? initialTempleData;

  const TempleDetailScreen({
    Key? key,
    required this.templeId,
    this.initialTempleData,
  }) : super(key: key);

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  Map<String, dynamic>? temple;
  bool isLoading = true;
  int selectedTab = 0;

  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> bills = [];
  List<String> suggestions = [];

  final TextEditingController _suggestionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  @override
  void dispose() {
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _loadTemple() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    temple = Map<String, dynamic>.from(widget.initialTempleData ?? {});

    if (temple!.isEmpty) {
      temple = {
        'id': widget.templeId,
        'name': 'Sample Temple',
        'status': 'pending',
        'projectId': 'P000',
        'userName': 'User',
        'userEmail': 'user@example.com',
        'userPhone': '+91 00000 00000',
        'userAadhar': '0000 0000 0000',
        'submittedDate': '2025-11-01',
        'village': 'Village',
        'town': 'Town',
        'taluk': 'Taluk',
        'district': 'District',
        'visitDate': '2025-10-28',
        'lingamType': 'New',
        'lingamDimensions': '3x2 feet',
        'avudaiType': 'Old',
        'avudaiDimensions': '-',
        'nandhiType': 'New',
        'nandhiDimensions': '4x3 feet',
        'localPerson': 'Local Person',
        'estimatedAmount': 100000.0,
        'siteImages': <String>[],
        'completedDate': null,
      };
    }

    temple!['status'] = (temple!['status'] ?? 'pending') as String;
    temple!['projectId'] = (temple!['projectId'] ?? 'P000') as String;
    temple!['name'] = (temple!['name'] ?? '') as String;
    temple!['userName'] = (temple!['userName'] ?? '') as String;
    temple!['userEmail'] = (temple!['userEmail'] ?? '') as String;
    temple!['userPhone'] = (temple!['userPhone'] ?? '') as String;
    temple!['userAadhar'] = (temple!['userAadhar'] ?? '') as String;
    temple!['village'] = (temple!['village'] ?? '') as String;
    temple!['town'] = (temple!['town'] ?? '') as String;
    temple!['taluk'] = (temple!['taluk'] ?? '') as String;
    temple!['district'] = (temple!['district'] ?? '') as String;
    temple!['visitDate'] = (temple!['visitDate'] ?? 'N/A') as String;
    temple!['localPerson'] = (temple!['localPerson'] ?? '') as String;
    temple!['lingamType'] = (temple!['lingamType'] ?? '') as String;
    temple!['lingamDimensions'] = (temple!['lingamDimensions'] ?? '-') as String;
    temple!['avudaiType'] = (temple!['avudaiType'] ?? '') as String;
    temple!['avudaiDimensions'] = (temple!['avudaiDimensions'] ?? '-') as String;
    temple!['nandhiType'] = (temple!['nandhiType'] ?? '') as String;
    temple!['nandhiDimensions'] = (temple!['nandhiDimensions'] ?? '-') as String;
    temple!['estimatedAmount'] = (temple!['estimatedAmount'] ?? 0.0) as num;
    temple!['completedDate'] = temple!['completedDate'];
    temple!['siteImages'] = List<String>.from(temple!['siteImages'] ?? []);

    if ((temple!['siteImages'] as List).isEmpty) {
      temple!['siteImages'] = [
        'https://picsum.photos/seed/site1/400/250',
        'https://picsum.photos/seed/site2/400/250',
      ];
    }

    activities = [
      {
        'id': 'a1',
        'title': 'Foundation Work',
        'date': '2025-11-05',
        'description': 'Excavation and foundation concrete work.',
        'status': 'pending',
        'images': [
          'https://picsum.photos/seed/activity1/400/250',
          'https://picsum.photos/seed/activity2/400/250',
        ],
      },
      {
        'id': 'a2',
        'title': 'Stone Work',
        'date': '2025-11-10',
        'description': 'Stone placement for base structure.',
        'status': 'completed',
        'images': ['https://picsum.photos/seed/activity3/400/250'],
      },
    ];

    transactions = [
      {
        'amount': 50000.0,
        'description': 'First phase payment',
        'paymentMode': 'cash',
        'date': '01/11/2025',
      },
      {
        'amount': 30000.0,
        'description': 'Stone purchase',
        'paymentMode': 'online',
        'date': '03/11/2025',
      },
    ];

    bills = [
      {
        'title': 'Stone purchase bill',
        'amount': 30000,
        'date': '03/11/2025',
        'imageUrl': 'https://picsum.photos/seed/bill1/400/250',
      },
      {
        'title': 'Mason labour bill',
        'amount': 20000,
        'date': '05/11/2025',
        'imageUrl': 'https://picsum.photos/seed/bill2/400/250',
      },
    ];

    suggestions = [
      'Ensure proper curing time before next phase.',
      'Send updated photos after foundation work.',
    ];

    setState(() => isLoading = false);
  }

  // UPDATED WITH FIRESTORE
  Future<void> _handleSanction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sanction Project'),
        content: const Text('Are you sure you want to sanction this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sanction'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.templeId)
            .update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': 'admin',
        });

        setState(() {
          temple!['status'] = 'approved';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project sanctioned successfully!')),
        );

        Navigator.pop(context, temple);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // UPDATED WITH FIRESTORE
  Future<void> _handleReject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Project'),
        content: const Text(
            'Are you sure you want to reject this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.templeId)
            .update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': 'admin',
        });

        setState(() {
          temple!['status'] = 'rejected';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project rejected successfully.')),
        );

        Navigator.pop(context, temple);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _handleMarkCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed'),
        content:
            const Text('Are you sure you want to mark this project as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        temple!['status'] = 'completed';
        temple!['completedDate'] = '2025-12-01';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project marked as completed!')),
      );
      Navigator.pop(context, temple);
    }
  }

  void _showAddTransactionDialog() {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String paymentMode = 'cash';
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                RadioListTile<String>(
                  title: const Text('Cash'),
                  value: 'cash',
                  groupValue: paymentMode,
                  onChanged: (value) {
                    setDialogState(() => paymentMode = value ?? 'cash');
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Online Payment'),
                  value: 'online',
                  groupValue: paymentMode,
                  onChanged: (value) {
                    setDialogState(() => paymentMode = value ?? 'online');
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date'),
                  subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (amountController.text.isEmpty || descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid amount')),
                  );
                  return;
                }

                setState(() {
                  transactions.add({
                    'amount': amount,
                    'description': descriptionController.text,
                    'paymentMode': paymentMode,
                    'date': '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  });
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction added successfully!')),
                );
              },
              child: const Text('Add Transaction'),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityDetail(Map<String, dynamic> activity) {
    final List<String> images = List<String>.from(activity['images'] ?? []);
    final String status = (activity['status'] ?? 'pending') as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      (activity['title'] ?? '') as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (activity['date'] ?? '') as String,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                (activity['description'] ?? '') as String,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Submitted Photos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (images.isEmpty)
                const Text(
                  'No photos uploaded for this activity.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                GridView.builder(
                  itemCount: images.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final url = images[index];
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: InteractiveViewer(
                              child: Image.network(url, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(url, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              if (status != 'completed')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        final idx = activities.indexWhere((a) => a['id'] == activity['id']);
                        if (idx != -1) activities[idx]['status'] = 'completed';
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Activity marked as completed.')),
                      );
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark this activity completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )
              else
                const Text(
                  'This activity is already completed.',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (temple == null) {
      return Scaffold(appBar: AppBar(title: const Text('Error')), body: const Center(child: Text('Temple not found')));
    }

    final status = (temple!['status'] ?? 'pending') as String;
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isCompleted = status == 'completed';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, temple);
        return false;
      },
      child: Scaffold(
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context, temple),
                      ),
                      Text(
                        (temple!['name'] ?? '') as String,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${temple!['projectId']} - ${status.toUpperCase()}',
                        style: const TextStyle(color: Color(0xFFC7D2FE), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (isApproved)
              Container(
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(child: _buildDetailTab('Activities', 0)),
                    Expanded(child: _buildDetailTab('Bills', 1)),
                    Expanded(child: _buildDetailTab('Suggestions', 2)),
                  ],
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildUserInfoCard(),
                  const SizedBox(height: 16),
                  if (isPending) ..._buildPendingView(),
                  if (isApproved) ..._buildOngoingView(),
                  if (isCompleted) ..._buildCompletedView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTab(String label, int index) {
    final isActive = selectedTab == index;
    return InkWell(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: isActive ? const Color(0xFF4F46E5) : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? const Color(0xFF4F46E5) : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text('User Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Name:', (temple!['userName'] ?? '') as String),
            _buildInfoRow('Email:', (temple!['userEmail'] ?? '') as String),
            _buildInfoRow('Phone:', (temple!['userPhone'] ?? '') as String),
            _buildInfoRow('Aadhar:', (temple!['userAadhar'] ?? '') as String),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPendingView() {
    return [
      _buildSiteImagesCard(),
      const SizedBox(height: 16),

      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFF4F46E5)),
                  SizedBox(width: 8),
                  Text('Location Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const Divider(height: 24),
              _buildInfoRow('Village:', (temple!['village'] ?? '') as String),
              _buildInfoRow('Town:', (temple!['town'] ?? '') as String),
              _buildInfoRow('Taluk:', (temple!['taluk'] ?? '') as String),
              _buildInfoRow('District:', (temple!['district'] ?? '') as String),
              _buildInfoRow('Visit Date:', (temple!['visitDate'] ?? '') as String),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Project Components', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 24),
              _buildComponentCard('Lingam', (temple!['lingamType'] ?? '') as String, (temple!['lingamDimensions'] ?? '-') as String),
              const SizedBox(height: 12),
              _buildComponentCard('Avudai', (temple!['avudaiType'] ?? '') as String, (temple!['avudaiDimensions'] ?? '-') as String),
              const SizedBox(height: 12),
              _buildComponentCard('Nandhi', (temple!['nandhiType'] ?? '') as String, (temple!['nandhiDimensions'] ?? '-') as String),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Contact & Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 24),
              _buildInfoRow('Local Contact:', (temple!['localPerson'] ?? '') as String),
              const SizedBox(height: 8),
              const Text('Estimated Amount:', style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text(
                '₹${(temple!['estimatedAmount'] as num).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleSanction,
              icon: const Icon(Icons.check),
              label: const Text('Sanction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleReject,
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildOngoingView() {
    final totalSpent = transactions.fold<num>(0, (prev, t) => prev + (t['amount'] ?? 0) as num);

    if (selectedTab == 0) {
      return [
        _buildSiteImagesCard(),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Project Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 24),
              _buildActivitiesSection(),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Total Spent: ₹${totalSpent.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                ],
              ),
              const Divider(height: 24),
              _buildTransactionsSection(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showAddTransactionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Transaction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Colors.green, Color(0xFF059669)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('All work completed for this temple?', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _handleMarkCompleted,
                icon: const Icon(Icons.check_circle),
                label: const Text('Mark Project as Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ];
    } else if (selectedTab == 1) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bills Uploaded by User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 24),
              _buildBillsSection(),
            ]),
          ),
        ),
      ];
    } else {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Previous Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 24),
              _buildSuggestionsList(),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add New Suggestion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: _suggestionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your suggestion for the user here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final text = _suggestionController.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a suggestion')),
                    );
                    return;
                  }

                  setState(() => suggestions.add(text));
                  _suggestionController.clear();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Suggestion sent to user!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                child: const Text('Send Suggestion'),
              ),
            ]),
          ),
        ),
      ];
    }
  }

  List<Widget> _buildCompletedView() {
    final completedDate = (temple!['completedDate'] ?? 'N/A')?.toString() ?? 'N/A';
    return [
      _buildSiteImagesCard(),
      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Project Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                Text('Completed on: $completedDate', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ]),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Project Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 24),
            _buildSummaryRow('Total Funds Released', '₹0'),
            _buildSummaryRow('Total Expenses', '₹0'),
            _buildSummaryRow('Activities Completed', activities.where((a) => a['status'] == 'completed').length.toString()),
            _buildSummaryRow('Total Visitors', '0'),
            _buildSummaryRow('Donations Received', '₹0'),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Completed Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 24),
            _buildActivitiesSection(onlyCompleted: true),
          ]),
        ),
      ),
    ];
  }

  Widget _buildSiteImagesCard() {
    final List<String> siteImages = List<String>.from(temple!['siteImages'] ?? []);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Site Images', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 24),
          if (siteImages.isEmpty)
            const Text('No site images available.', style: TextStyle(color: Colors.grey, fontSize: 14))
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: siteImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = siteImages[index];
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(child: Image.network(url, fit: BoxFit.cover)),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 240, height: 180, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildActivitiesSection({bool onlyCompleted = false}) {
    final list = onlyCompleted
        ? activities.where((a) => a['status'] == 'completed').toList()
        : activities;

    if (list.isEmpty) {
      return const Text('No activities yet', style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.map((a) {
        final title = (a['title'] ?? '') as String;
        final date = (a['date'] ?? '') as String;
        final status = (a['status'] ?? 'pending') as String;
        final isCompleted = status == 'completed';

        return InkWell(
          onTap: () => _showActivityDetail(a),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isCompleted ? Colors.green : const Color(0xFFE5E7EB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18, color: isCompleted ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (date.isNotEmpty) Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionsSection() {
    if (transactions.isEmpty) {
      return const Text('No transactions yet', style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: transactions.map((t) {
        final amount = (t['amount'] ?? 0.0) as num;
        final description = (t['description'] ?? '') as String;
        final paymentMode = (t['paymentMode'] ?? '') as String;
        final date = (t['date'] ?? '') as String;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.account_balance_wallet, color: Color(0xFF4F46E5)),
          title: Text('₹${amount.toStringAsFixed(0)} - $description',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${paymentMode.toUpperCase()} • $date',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        );
      }).toList(),
    );
  }

  Widget _buildBillsSection() {
    if (bills.isEmpty) {
      return const Text('No bills uploaded yet', style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: bills.map((b) {
        final title = (b['title'] ?? 'Bill') as String;
        final amount = (b['amount'] ?? 0) as num;
        final date = (b['date'] ?? '') as String;
        final imageUrl = (b['imageUrl'] ?? '') as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: imageUrl.isEmpty
                ? const Icon(Icons.receipt_long, color: Colors.blue)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                  ),
            title: Text(title),
            subtitle: Text('Amount: ₹$amount • Date: $date',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () {
              if (imageUrl.isEmpty) return;
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.cover)),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuggestionsList() {
    if (suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No suggestions yet', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: suggestions.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.message, size: 16, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(child: Text(s, style: const TextStyle(fontSize: 14))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComponentCard(String name, String type, String dimensions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: const Color(0xFF4F46E5), width: 4)),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Type: $type', style: const TextStyle(fontSize: 13)),
          if (dimensions != '-')
            Text('Dimensions: $dimensions', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
        ],
      ),
    );
  }
}
