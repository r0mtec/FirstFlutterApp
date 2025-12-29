import 'package:flutter/material.dart';
import 'package:lab/data/repositories/openlibrary_repository.dart';
import 'package:lab/domain/models/card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller =
  TextEditingController(text: 'harry potter');
  String _query = 'harry potter';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final value = _controller.text.trim();
    setState(() {
      _query = value.isEmpty ? 'harry potter' : value;
    });
  }

  void _navToDetails(BuildContext context, CardData data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailsPage(data: data),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = OpenLibraryRepository().loadData(_query);

    return Scaffold(
      appBar: AppBar(title: const Text('Lab 5 — API + DTO + Repo')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Поиск книг (OpenLibrary)',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _search,
                  child: const Text('Найти'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<CardData>?>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Ошибка: ${snapshot.error}'),
                    );
                  }

                  final data = snapshot.data;
                  if (data == null) {
                    return const Center(child: Text('Ошибка загрузки (data == null)'));
                  }

                  if (data.isEmpty) {
                    return const Center(child: Text('Ничего не найдено'));
                  }

                  return ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];
                      return AppCard(
                        data: item,
                        onTap: () => _navToDetails(context, item),
                        onLongPress: () => _showSnackBar(
                          context,
                          'Открываю: ${item.text}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final CardData data;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AppCard({
    super.key,
    required this.data,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(data.icon, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(data.descriptionText),
                    if (data.imageUrl != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          data.imageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const SizedBox(
                            height: 180,
                            child: Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  final CardData data;

  const DetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(data.text)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  data.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 220,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              data.text,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.descriptionText,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 18),
            const Text(
              'Детальная информация',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Тут можно вывести любые дополнительные поля, описание, '
                  'ссылки, рейтинг, список авторов и т.д.',
            ),
          ],
        ),
      ),
    );
  }
}
