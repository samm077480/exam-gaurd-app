import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase initialize karein (Firebase setup hone par activate karein)
  // await Firebase.initializeApp();
  runApp(const ExamGuardApp());
}

class ExamGuardApp extends StatelessWidget {
  const ExamGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamGuard Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// -------------------------------------------------------------
// 1. ROLE SELECTION SCREEN
// -------------------------------------------------------------
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _roomController = TextEditingController(text: "COLLEGE101");
  final _nameController = TextEditingController();
  final _passController = TextEditingController(text: "1234");
  String _selectedRole = "Student";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ExamGuard Security")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 60, color: Colors.indigoAccent),
                    const SizedBox(height: 10),
                    const Text("Join Exam Room", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Student', label: Text('Student')),
                        ButtonSegment(value: 'Admin', label: Text('Admin (Teacher)')),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (val) => setState(() => _selectedRole = val.first),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _roomController,
                      decoration: const InputDecoration(labelText: "Room Code", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: _selectedRole == "Admin" ? "Teacher Name" : "Student Name / Roll No",
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Admin Key / Unlock Password", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.indigoAccent,
                      ),
                      onPressed: () {
                        if (_nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Kripya apna naam bharein!")),
                          );
                          return;
                        }

                        if (_selectedRole == "Admin") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminDashboardScreen(
                                roomCode: _roomController.text,
                                adminPass: _passController.text,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentExamScreen(
                                roomCode: _roomController.text,
                                studentName: _nameController.text,
                                adminPass: _passController.text,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(_selectedRole == "Admin" ? "Start Admin Console" : "Enter Exam Room"),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. STUDENT EXAM SCREEN (ANTI-CHEATING ACTIVE)
// -------------------------------------------------------------
class StudentExamScreen extends StatefulWidget {
  final String roomCode;
  final String studentName;
  final String adminPass;

  const StudentExamScreen({
    super.key,
    required this.roomCode,
    required this.studentName,
    required this.adminPass,
  });

  @override
  State<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends State<StudentExamScreen> with WidgetsBindingObserver {
  bool _isLockedOut = false;
  int _violationCount = 0;
  final TextEditingController _unlockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secureApp(); // Screenshot block karein
  }

  // FLAG_SECURE: Prevent Screenshots and App Switch Previews
  Future<void> _secureApp() async {
    try {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } catch (e) {
      debugPrint("FLAG_SECURE error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // App background me jaane par detection (Tab/App Switch Detection)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _triggerLockout("App minimize ya background me bheja gaya!");
    }
  }

  void _triggerLockout(String reason) {
    if (_isLockedOut) return;
    setState(() {
      _isLockedOut = true;
      _violationCount++;
    });

    // Send violation log to Firestore
    /*
    FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).collection('students').doc(widget.studentName).set({
      'status': 'LOCKED',
      'violations': _violationCount,
      'lastViolation': reason,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    */
  }

  void _unlockExam() {
    if (_unlockController.text == widget.adminPass) {
      setState(() {
        _isLockedOut = false;
        _unlockController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Galat Password! Admin se contact karein.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Back Button disable karein exam ke dauran
        _triggerLockout("Back button dabane ki koshish ki!");
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Exam Room: ${widget.roomCode}"),
          automaticallyImplyLeading: false,
          actions: [
            Chip(
              avatar: const Icon(Icons.warning, color: Colors.orange, size: 16),
              label: Text("Violations: $_violationCount"),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Stack(
          children: [
            // Normal Question Screen
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: const Color(0xFF1E293B),
                    child: ListTile(
                      title: Text("Candidate: ${widget.studentName}"),
                      subtitle: const Text("Status: SECURE (Screen Monitored)"),
                      leading: const Icon(Icons.person, color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Question 1 of 5", style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 10),
                  const Text(
                    "What is the main function of an Operating System?",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ...[
                    "A. Manage Hardware Resources",
                    "B. Compile Source Code",
                    "C. Design Web Pages",
                    "D. Generate Power"
                  ].map((option) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: RadioListTile(
                          title: Text(option),
                          value: option,
                          groupValue: null,
                          onChanged: (val) {},
                        ),
                      )),
                ],
              ),
            ),

            // Anti-Cheating Lockout Overlay (Agar student app chhodta h)
            if (_isLockedOut)
              Container(
                color: Colors.black.withOpacity(0.95),
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 80, color: Colors.redAccent),
                      const SizedBox(height: 20),
                      const Text(
                        "EXAM LOCKED!",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Aapne app switch karne ya background me jaane ki koshish ki. Dubara continue karne ke liye Admin Password dalein.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: _unlockController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Admin Password Type Karein",
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: _unlockExam,
                        child: const Text("Unlock & Resume Exam"),
                      )
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. ADMIN DASHBOARD (70 PARTICIPANTS MONITORING)
// -------------------------------------------------------------
class AdminDashboardScreen extends StatelessWidget {
  final String roomCode;
  final String adminPass;

  const AdminDashboardScreen({
    super.key,
    required this.roomCode,
    required this.adminPass,
  });

  @override
  Widget build(BuildContext context) {
    // Dummy List of 70 Students (Aap ise Firestore StreamBuilder se replace kar sakte hain)
    final List<Map<String, dynamic>> students = List.generate(
      70,
      (index) => {
        "id": index + 1,
        "name": "Student ${index + 1}",
        "status": index == 3 ? "LOCKED" : (index == 7 ? "WARNING" : "ACTIVE"),
        "violations": index == 3 ? 2 : (index == 7 ? 1 : 0),
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Monitor - Room: $roomCode"),
        subtitle: Text("Master Key: $adminPass"),
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Text("Total: 70", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Active: 68", style: TextStyle(color: Colors.green)),
                Text("Locked: 2", style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
          // 70 Participants Real-time Grid View
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // Grid Columns
                childAspectRatio: 1.1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                Color cardColor = Colors.green.shade900;
                if (student["status"] == "LOCKED") cardColor = Colors.red.shade900;
                if (student["status"] == "WARNING") cardColor = Colors.orange.shade900;

                return Card(
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          student["status"] == "LOCKED" ? Icons.lock : Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          student["name"],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Violations: ${student["violations"]}",
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
