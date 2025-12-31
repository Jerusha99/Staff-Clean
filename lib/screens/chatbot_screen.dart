import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  final Map<String, String> _qaPairs = {
    // General Questions
    'What are the cleaning schedules?': 'Cleaning schedules are available in the "Tasks" section, where you can see all upcoming and in-progress cleaning tasks.',
    'How do I report a completed task?': 'You can mark a task as completed from the task details screen. Navigate to the task and update its status.',
    'Where can I see my assigned tasks?': 'Your assigned tasks are listed on your dashboard. You can also find them in the "Tasks" screen, filtered by your name.',
    'How do I edit my profile?': 'You can edit your profile by tapping on the person icon in the top right of your dashboard, or through the drawer menu.',

    // Admin-Specific Questions
    'How to add a new staff member?': 'Only admins can add new staff members. This can be done from the "Staff Management" section in the admin dashboard.',
    'What is the task analytics report?': 'The task analytics report, available to admins, provides insights into task completion rates, tasks per area, and overall staff performance.',
    'How can I add a new task?': 'As an admin, you can add a new task by tapping the "+" button on the "All Tasks" screen.',
    'Can I delete a task?': 'Yes, admins can delete tasks by swiping them to the left on the "All Tasks" screen.',

    // Staff-Specific Questions
    'How do I view task details?': 'You can view the details of a task by tapping on it from your task list.',
    'What do the different colors on tasks mean?': 'The colors on the tasks represent the cleaning area, helping you to quickly identify the location of the task.',
    'Can I change my password?': 'Password changes are not yet available in the app. Please contact an administrator for assistance.',
  };

  @override
  void initState() {
    super.initState();
    _addSupportMessage('Hello! How can I help you today?');
  }

  void _addSupportMessage(String message) {
    setState(() {
      _messages.insert(0, {'sender': 'support', 'text': message});
    });
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.insert(0, {'sender': 'user', 'text': text});
      _isTyping = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      String response = _getSupportResponse(text);
      setState(() {
        _isTyping = false;
        _messages.insert(0, {'sender': 'support', 'text': response});
      });
    });
  }

  String _getSupportResponse(String query) {
    String lowerCaseQuery = query.toLowerCase().trim();
    for (var question in _qaPairs.keys) {
      if (question.toLowerCase() == lowerCaseQuery) {
        return _qaPairs[question]!;
      }
    }
    return "I'm sorry, I don't have an answer for that. Please try asking one of the suggested questions or rephrasing your question.";
  }

  Widget _buildMessage(Map<String, String> message) {
    bool isUser = message['sender'] == 'user';
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isUser)
          const Padding(
            padding: EdgeInsets.only(left: 8.0),
            child: CircleAvatar(
              child: Icon(Icons.support_agent),
            ),
          ),
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: isUser ? Theme.of(context).primaryColor : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20.0),
                topRight: const Radius.circular(20.0),
                bottomLeft: isUser ? const Radius.circular(20.0) : Radius.zero,
                bottomRight: isUser ? Radius.zero : const Radius.circular(20.0),
              ),
            ),
            child: Text(
              message['text']!,
              style: TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
          ),
        ),
        if (isUser)
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Icon(Icons.support_agent),
                  ),
                  SizedBox(width: 10),
                  Text('Support is typing...'),
                ],
              ),
            ),
          const Divider(height: 1.0),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _qaPairs.keys.map((question) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      label: Text(question),
                      onPressed: () {
                        _handleSubmitted(question);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: _handleSubmitted,
                      decoration: InputDecoration(
                        hintText: 'Send a message',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  FloatingActionButton(
                    mini: true,
                    onPressed: () => _handleSubmitted(_controller.text),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
