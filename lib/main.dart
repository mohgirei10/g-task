import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io'; 
import 'package:image_picker/image_picker.dart';

void main() => runApp(const ModernTodoApp());

// --- DATA MODEL ---
class Todo {
  String title;
  DateTime date;
  bool isDone;
  String category;

  Todo({
    required this.title,
    required this.date,
    this.isDone = false,
    this.category = "General",
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date.toIso8601String(),
        'isDone': isDone,
        'category': category
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        title: json['title'],
        date: DateTime.parse(json['date']),
        isDone: json['isDone'],
        category: json['category'] ?? "General",
      );
}

class ModernTodoApp extends StatefulWidget {
  const ModernTodoApp({super.key});

  @override
  State<ModernTodoApp> createState() => _ModernTodoAppState();
}

class _ModernTodoAppState extends State<ModernTodoApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        primaryColor: const Color(0xFFFF7D54),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFFFF7D54),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: TodoDashboard(
        onThemeToggle: toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class TodoDashboard extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  const TodoDashboard({super.key, required this.onThemeToggle, required this.isDarkMode});

  @override
  State<TodoDashboard> createState() => _TodoDashboardState();
}

class _TodoDashboardState extends State<TodoDashboard> {
  List<Todo> _tasks = [];
  DateTime _selectedDate = DateTime.now();
  String _userName = "User";
  String? _imagePath;
  String _activeCategoryFilter = "All";

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "";
      _imagePath = prefs.getString('profile_path');
      final taskData = prefs.getString('tasks_v5');
      if (taskData != null) {
        _tasks = (json.decode(taskData) as List).map((t) => Todo.fromJson(t)).toList();
      }
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasks_v5', json.encode(_tasks.map((t) => t.toJson()).toList()));
  }

  Widget _buildProgressCard(int total, int completed) {
    double progress = total == 0 ? 0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 0, 172, 106), Color.fromARGB(255, 0, 172, 106)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Daily Progress", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.black.withValues(alpha: 0.1),
              color: Colors.black,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Text("$completed of $total tasks done", style: TextStyle(color: Colors.black.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    List<String> dynamicFilters = ["All", "General", "Work", "Personal"];
    for (var task in _tasks) {
      if (!dynamicFilters.contains(task.category)) {
        dynamicFilters.add(task.category);
      }
    }

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dynamicFilters.length,
        itemBuilder: (context, index) {
          bool isSelected = _activeCategoryFilter == dynamicFilters[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(dynamicFilters[index]),
              selected: isSelected,
              onSelected: (val) => setState(() => _activeCategoryFilter = dynamicFilters[index]),
              selectedColor: const Color(0xFFFF7D54),
              labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSearching = _searchController.text.isNotEmpty;

    final List<Todo> displayList = isSearching 
      ? _tasks.where((t) {
          bool matchesSearch = t.title.toLowerCase().contains(_searchController.text.toLowerCase());
          bool matchesCategory = _activeCategoryFilter == "All" || t.category == _activeCategoryFilter;
          return matchesSearch && matchesCategory;
        }).toList()
      : _tasks.where((t) {
          bool matchesDate = t.date.year == _selectedDate.year && t.date.month == _selectedDate.month && t.date.day == _selectedDate.day;
          bool matchesCategory = _activeCategoryFilter == "All" || t.category == _activeCategoryFilter;
          return matchesDate && matchesCategory;
        }).toList();

    int totalToday = _tasks.where((t) => t.date.day == _selectedDate.day).length;
    int completedToday = _tasks.where((t) => t.date.day == _selectedDate.day && t.isDone).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildProgressCard(totalToday, completedToday),
              const SizedBox(height: 25),
              _buildSearchBar(),
              const SizedBox(height: 15),
              _buildFilterBar(),
              const SizedBox(height: 10),
              _buildTimeline(),
              const SizedBox(height: 15),
              Expanded(
                child: ListView(
                  children: [
                    if (displayList.where((t) => !t.isDone).isNotEmpty) ...[
                      _sectionHeader("Pending Tasks"),
                      ...displayList.where((t) => !t.isDone).map((t) => _taskTile(t)),
                    ],
                    if (displayList.where((t) => t.isDone).isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionHeader("Completed"),
                      ...displayList.where((t) => t.isDone).map((t) => _taskTile(t)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    "Developed by Mohammed Girei",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.withValues(alpha: 0.6),
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 35.0), 
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFFF7D54),
          onPressed: _showAddTask,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _editProfile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hello, $_userName", style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800)),
              Text(DateFormat('EEEE, MMM d').format(DateTime.now()), style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
        GestureDetector(
          onTap: _editProfile,
          child: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white10,
            backgroundImage: _imagePath != null ? FileImage(File(_imagePath!)) : null,
            child: _imagePath == null ? const Icon(Icons.person, color: Colors.white) : null,
          ),
        )
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {}),
        style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey), 
          hintText: "Search tasks...", 
          border: InputBorder.none, 
          hintStyle: TextStyle(color: Colors.grey)
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          bool isSelected = date.day == _selectedDate.day;
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 65,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFF7D54) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E').format(date), style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontWeight: FontWeight.bold)),
                  Text(date.day.toString(), style: TextStyle(color: isSelected ? Colors.black : (widget.isDarkMode ? Colors.white : Colors.black), fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _taskTile(Todo todo) {
    return Dismissible(
      key: ObjectKey(todo),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (dir) {
        setState(() => _tasks.remove(todo));
        _saveTasks();
        HapticFeedback.heavyImpact();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            IconButton(
              icon: Icon(todo.isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: const Color(0xFFFF7D54)),
              onPressed: () {
                setState(() => todo.isDone = !todo.isDone);
                _saveTasks();
                HapticFeedback.lightImpact();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(todo.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, decoration: todo.isDone ? TextDecoration.lineThrough : null)),
                  Row(
                    children: [
                      Text(DateFormat('MMM d').format(todo.date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Text("•", style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(todo.category, style: const TextStyle(color: Color(0xFFFF7D54), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  void _editProfile() {
    _nameController.text = _userName;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Profile Settings", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: "Enter Name", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await _picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('profile_path', picked.path);
                        setState(() => _imagePath = picked.path);
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: const Text("Photo"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7D54)),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('user_name', _nameController.text);
                      setState(() => _userName = _nameController.text);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text("Save", style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showAddTask() {
    final TextEditingController taskController = TextEditingController();
    final TextEditingController customCatController = TextEditingController();
    // ignore: unused_local_variable
    final subTaskController = TextEditingController();
    String selectedCategory = "General";
    bool isCustom = false;
    List<String> categories = ["General", "Work" "Personal", "Custom"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("New Task", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),
              TextField(
                controller: taskController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: "What's the plan?", hintStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 20),
              const Text("Category", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: categories.map((cat) {
                  bool isSelected = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFF7D54),
                    onSelected: (val) {
                      setModalState(() {
                        selectedCategory = cat;
                        isCustom = (cat == "Custom");
                      });
                    },
                  );
                }).toList(),
              ),
              if (isCustom) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: customCatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter custom category name",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7D54), minimumSize: const Size(double.infinity, 50)),
                onPressed: () {
                  if (taskController.text.isNotEmpty) {
                    String finalCat = isCustom ? (customCatController.text.isEmpty ? "General" : customCatController.text) : selectedCategory;
                    setState(() => _tasks.add(Todo(
                          title: taskController.text,
                          date: _selectedDate,
                          category: finalCat,
                        )));
                    _saveTasks();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Save Task", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}