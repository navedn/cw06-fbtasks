import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _startTimeController =
      MaskedTextController(mask: '00:00');
  final TextEditingController _endTimeController = TextEditingController();
  bool _isAM = true;

  String? _selectedDay;
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  // Function to add task to Firebase
  Future<void> _addTask() async {
    if (_taskNameController.text.isNotEmpty && _selectedDay != null) {
      String startTime24 = _convertTo24Hour(_startTimeController.text, _isAM);

      await _firestore.collection('tasks').add({
        'day': _selectedDay,
        'name': _taskNameController.text,
        'startTime': startTime24,
        'endTime': _endTimeController.text,
        'completed': false,
        'userId': _auth.currentUser!.uid,
      });
      _taskNameController.clear();
      _startTimeController.clear();
      _endTimeController.clear();
    }
  }

  // Function to toggle task completion status
  Future<void> _toggleTaskCompletion(String taskId, bool currentStatus) async {
    await _firestore
        .collection('tasks')
        .doc(taskId)
        .update({'completed': !currentStatus});
  }

  // Function to delete a task
  Future<void> _deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  Future<void> _signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  String _convertTo24Hour(String time, bool isAM) {
    int hour = int.parse(time.split(':')[0]);
    final minute = time.split(':')[1];

    if (isAM && hour == 12) hour = 0; // Convert 12 AM to 00
    if (!isAM && hour != 12) hour += 12; // Convert PM times

    return '$hour:$minute'; // Returns in HH:mm format
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Task Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _taskNameController,
                  decoration: InputDecoration(labelText: 'Task Name'),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedDay,
                  items: _daysOfWeek.map((day) {
                    return DropdownMenuItem(value: day, child: Text(day));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedDay = value),
                  decoration: InputDecoration(labelText: 'Day of the Week'),
                ),
                TextField(
                  controller: _startTimeController,
                  decoration: InputDecoration(labelText: 'Start Time (HH:MM)'),
                  keyboardType: TextInputType.number,
                ),
                Row(
                  children: [
                    Text('AM / PM:'),
                    SizedBox(width: 8),
                    ToggleButtons(
                      isSelected: [_isAM, !_isAM],
                      onPressed: (index) {
                        setState(() {
                          _isAM = index == 0;
                        });
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('AM'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('PM'),
                        ),
                      ],
                    ),
                  ],
                ),
                TextField(
                  controller: _endTimeController,
                  decoration:
                      InputDecoration(labelText: 'End Time (HH:MM AM/PM)'),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _addTask,
                  child: Text('Add Task'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: _daysOfWeek.map((day) {
                return ExpansionTile(
                  title: Text(day),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('tasks')
                          .where('day', isEqualTo: day)
                          .where('userId', isEqualTo: _auth.currentUser!.uid)
                          .orderBy('startTime')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child:
                                  CircularProgressIndicator()); // Show loading spinner while waiting for data
                        }
                        if (snapshot.hasError) {
                          debugPrint('${snapshot.error}');
                          return Center(
                              child: Text(
                                  'Error: ${snapshot.error}')); // Handle error state
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                                'No tasks for $day'), // Handle empty data state
                          );
                        }

                        final tasks = snapshot.data!.docs;
                        return Column(
                          children: tasks.map((task) {
                            final taskData =
                                task.data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(taskData['name']),
                              subtitle: Text(
                                  '${taskData['startTime']} - ${taskData['endTime']}'),
                              leading: Checkbox(
                                value: taskData['completed'],
                                onChanged: (value) => _toggleTaskCompletion(
                                    task.id, taskData['completed']),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => _deleteTask(task.id),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    )
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ProfileScreen remains the same as provided in your initial code
// Include Firebase authentication in the main file and setup Firebase properly
