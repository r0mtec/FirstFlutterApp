import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BooksSearchPage(),
    );
  }
}

class BookDto {
  final String title;
  final String? author;
  final int? firstPublishYear;
  final int? coverId;

  const BookDto({
    required this.title,
    required this.author,
    required this.firstPublishYear,
    required this.coverId,
  });

  factory BookDto.fromJson(Map<String, dynamic> json) {
    final authors = json['author_name'];
    String? author;
    if (authors is List && authors.isNotEmpty) {
      author = authors.first?.toString();
    }

    return BookDto(
      title: (json['title'] ?? 'Без названия').toString(),
      author: author,
      firstPublishYear: json['first_publish_year'] is int
          ? json['first_publish_year'] as int
          : null,
      coverId: json['cover_i'] is int ? json['cover_i'] as int : null,
    );
  }

  String? get coverUrl {
    if (coverId == null) return null;
    return 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';
  }
}


abstract class IBooksRepository {
  Future<List<BookDto>> searchBooks(String query);
}


class OpenLibraryBooksRepository implements IBooksRepository {
  final http.Client _client;

  OpenLibraryBooksRepository({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<BookDto>> searchBooks(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return <BookDto>[];

    final uri = Uri.parse('https://openlibrary.org/search.json')
        .replace(queryParameters: <String, String>{'q': trimmed});

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> data =
    jsonDecode(response.body) as Map<String, dynamic>;

    final docs = data['docs'];
    if (docs is! List) return <BookDto>[];

    final items = docs.take(20);

    return items
        .whereType<Map<String, dynamic>>()
        .map(BookDto.fromJson)
        .toList(growable: false);
  }
}


class BooksSearchPage extends StatefulWidget {
  const BooksSearchPage({super.key});

  @override
  State<BooksSearchPage> createState() => _BooksSearchPageState();
}

class _BooksSearchPageState extends State<BooksSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final IBooksRepository _repo = OpenLibraryBooksRepository();

  bool _loading = false;
  String? _error;
  List<BookDto> _books = const [];

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repo.searchBooks(_controller.text);
      setState(() {
        _books = result;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _openDetails(BookDto book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailsPage(book: book),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Лаба 5 — Search API')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      labelText: 'Поиск книг (например: harry potter)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  child: const Text('Найти'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _books.isEmpty && !_loading
                  ? const Center(child: Text('Введите запрос и нажмите “Найти”.'))
                  : ListView.builder(
                itemCount: _books.length,
                itemBuilder: (context, index) {
                  final book = _books[index];
                  return Card(
                    child: ListTile(
                      leading: _CoverImage(url: book.coverUrl),
                      title: Text(book.title),
                      subtitle: Text(
                        'Автор: ${book.author ?? "не указан"}\n'
                            'Год: ${book.firstPublishYear?.toString() ?? "—"}',
                      ),
                      isThreeLine: true,
                      onTap: () => _openDetails(book),
                    ),
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

class _CoverImage extends StatelessWidget {
  final String? url;

  const _CoverImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const SizedBox(
        width: 48,
        height: 64,
        child: Icon(Icons.menu_book),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url!,
        width: 48,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 48,
          height: 64,
          child: Icon(Icons.broken_image),
        ),
      ),
    );
  }
}

class BookDetailsPage extends StatelessWidget {
  final BookDto book;

  const BookDetailsPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Детали')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: _CoverImage(url: book.coverUrl),
          ),
          const SizedBox(height: 16),
          Text(
            book.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text('Автор: ${book.author ?? "не указан"}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text('Год первой публикации: ${book.firstPublishYear?.toString() ?? "—"}',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          const Text(
            'Детальная информация (пример):\n'
                '• Источник данных: OpenLibrary Search API\n'
                '• Запрос выполняется по параметру q\n'
                '• DTO: BookDto\n'
                '• Repository: IBooksRepository / OpenLibraryBooksRepository',
            style: TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
