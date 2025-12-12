// lib/lab2.dart

enum TaskPriority {
  low,
  medium,
  high,
}

class Task {
  final int id;
  String title;
  TaskPriority priority;
  bool isDone;

  Task({
    required this.id,
    required this.title,
    required this.priority,
    this.isDone = false,
  });

  void toggleDone() {
    isDone = !isDone;
  }

  @override
  String toString() {
    final doneMark = isDone ? "✔️" : "❌";
    return "[$doneMark] #$id $title (${priority.name})";
  }
}

class TaskManager {
  final List<Task> _tasks = <Task>[];

  List<Task> get tasks {
    return _tasks;
  }

  void addTask(Task task) {
    _tasks.add(task);
  }

  void removeById(int id) {
    _tasks.removeWhere((t) => t.id == id);
  }

  Task? findById(int id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  List<Task> filter(bool Function(Task) predicate) {
    final result = <Task>[];

    for (final task in _tasks) {
      if (predicate(task)) {
        result.add(task);
      }
    }

    return result;
  }

  void sortByPriorityDesc() {
    _tasks.sort((a, b) => b.priority.index.compareTo(a.priority.index));
  }

  void printAll() {
    if (_tasks.isEmpty) {
      print("Список задач пуст.");
      return;
    }

    for (final task in _tasks) {
      print(task);
    }
  }
}


extension StringExtensions on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}


Future<List<Task>> fetchInitialTasks() async {
  await Future.delayed(const Duration(milliseconds: 500));

  return <Task>[
    Task(id: 1, title: "купить молоко".capitalize(), priority: TaskPriority.low),
    Task(id: 2, title: "сделать лабу по dart".capitalize(), priority: TaskPriority.high),
    Task(id: 3, title: "пройтись пешком".capitalize(), priority: TaskPriority.medium),
  ];
}

Future<void> runLab2() async {
  final manager = TaskManager();

  final List<Task> initial = await fetchInitialTasks();
  for (final task in initial) {
    manager.addTask(task);
  }

  final onlyHigh = manager.filter((t) => t.priority == TaskPriority.high);

  print("=== Все задачи (после загрузки) ===");
  manager.printAll();

  print("\n=== Только high (через filter с anonymous function) ===");
  for (final t in onlyHigh) {
    print(t);
  }

  int doneCount = 0;
  int i = 0;

  while (i < manager.tasks.length) {
    if (manager.tasks[i].isDone) {
      doneCount++;
    }
    i++;
  }

  print("\nВыполненных задач сейчас: $doneCount");

  final task2 = manager.findById(2);
  task2?.toggleDone();

  manager.sortByPriorityDesc();

  print("\n=== После toggleDone у #2 и сортировки по приоритету ===");
  manager.printAll();
}
