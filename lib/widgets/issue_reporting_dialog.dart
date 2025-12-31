import 'package:staff_cleaning/models/issue.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:flutter/material.dart';

class IssueReportingDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const IssueReportingDialog({super.key, required this.userId, required this.userName});

  @override
  State<IssueReportingDialog> createState() => _IssueReportingDialogState();
}

class _IssueReportingDialogState extends State<IssueReportingDialog> {
  final _formKey = GlobalKey<FormState>();
  String _issueType = 'Lack of Tools';
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _reportIssue() async {
    if (_formKey.currentState!.validate()) {
      final issue = Issue(
        id: '', // Firebase will generate this
        userId: widget.userId,
        userName: widget.userName,
        issueType: _issueType,
        description: _descriptionController.text,
        timestamp: DateTime.now(),
      );
      await _firebaseService.reportIssue(issue);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Issue reported successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report an Issue'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _issueType, // Changed from value to initialValue
                decoration: const InputDecoration(labelText: 'Issue Type'),
                items: <String>['Lack of Tools', 'Blocked Room', 'Water Issue', 'Other']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _issueType = newValue!;
                  });
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _reportIssue,
          child: const Text('Report'),
        ),
      ],
    );
  }
}
