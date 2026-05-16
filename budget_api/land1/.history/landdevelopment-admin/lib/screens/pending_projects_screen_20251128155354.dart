import 'package:flutter/material.dart';
import '../services/admin_project_service.dart';

class PendingProjectsScreen extends StatelessWidget {
  final service = AdminProjectService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pending Projects")),
      body: StreamBuilder(
        stream: service.fetchPendingProjects(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(child: Text("No pending projects"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var id = docs[index].id;
              var data = docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.all(12),
                child: ListTile(
                  title: Text(data['place']),
                  subtitle: Text("Feature: ${data['feature']}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () => service.approve(id),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.red),
                        onPressed: () => service.reject(id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
