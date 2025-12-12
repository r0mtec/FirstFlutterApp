import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
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

  OpenLibraryBooksRepository({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<BookDto>> searchBooks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return <BookDto>[];

    final uri = Uri.parse('https://openlibrary.org/search.json')
        .replace(queryParameters: {'q': q});

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> data =
    jsonDecode(response.body) as Map<String, dynamic>;

    final docs = data['docs'];
    if (docs is! List) return <BookDto>[];

    return docs
        .take(20)
        .whereType<Map<String, dynamic>>()
        .map(BookDto.fromJson)
        .toList(growable: false);
  }
}



sealed class BooksEvent extends Equatable {
  const BooksEvent();

  @override
  List<Object?> get props => [];
}

class BooksQueryChanged extends BooksEvent {
  final String query;

  const BooksQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class BooksRefreshRequested extends BooksEvent {
  const BooksRefreshRequested();
}


class BooksState extends Equatable {
  final String query;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final List<BookDto> books;

  const BooksState({
    required this.query,
    required this.isLoading,
    required this.isRefreshing,
    required this.error,
    required this.books,
  });

  factory BooksState.initial() => const BooksState(
    query: '',
    isLoading: false,
    isRefreshing: false,
    error: null,
    books: <BookDto>[],
  );

  BooksState copyWith({
    String? query,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<BookDto>? books,
    bool clearError = false,
  }) {
    return BooksState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      books: books ?? this.books,
    );
  }

  @override
  List<Object?> get props => [query, isLoading, isRefreshing, error, books];
}


EventTransformer<T> debounce<T>(Duration duration) {
  return (events, mapper) {
    return events.debounceTime(duration).switchMap(mapper);
  };
}


extension _StreamDebounce<T> on Stream<T> {
  Stream<T> debounceTime(Duration duration) {
    Timer? timer;
    StreamController<T>? controller;

    controller = StreamController<T>(
      onListen: () {
        final sub = listen(
              (event) {
            timer?.cancel();
            timer = Timer(duration, () {
              if (!controller!.isClosed) controller.add(event);
            });
          },
          onError: controller!.addError,
          onDone: () async {
            timer?.cancel();
            await controller!.close();
          },
          cancelOnError: false,
        );

        controller!.onCancel = () async {
          timer?.cancel();
          await sub.cancel();
        };
      },
    );

    return controller.stream;
  }

  Stream<R> switchMap<R>(Stream<R> Function(T) mapper) {
    StreamController<R>? controller;
    StreamSubscription<T>? outerSub;
    StreamSubscription<R>? innerSub;

    controller = StreamController<R>(
      onListen: () {
        outerSub = listen((event) async {
          await innerSub?.cancel();
          innerSub = mapper(event).listen(
            controller!.add,
            onError: controller!.addError,
          );
        }, onError: controller!.addError, onDone: () async {
          await innerSub?.cancel();
          await controller!.close();
        });

        controller!.onCancel = () async {
          await innerSub?.cancel();
          await outerSub?.cancel();
        };
      },
    );

    return controller.stream;
  }
}


class BooksBloc extends Bloc<BooksEvent, BooksState> {
  final IBooksRepository _repo;

  BooksBloc(this._repo) : super(BooksState.initial()) {
    on<BooksQueryChanged>(
      _onQueryChanged,
      transformer: debounce(const Duration(milliseconds: 450)),
    );
    on<BooksRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onQueryChanged(
      BooksQueryChanged event,
      Emitter<BooksState> emit,
      ) async {
    final newQuery = event.query;

    emit(state.copyWith(
      query: newQuery,
      isLoading: true,
      clearError: true,
    ));

    try {
      final books = await _repo.searchBooks(newQuery);
      emit(state.copyWith(
        isLoading: false,
        books: books,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Ошибка загрузки: $e',
      ));
    }
  }

  Future<void> _onRefreshRequested(
      BooksRefreshRequested event,
      Emitter<BooksState> emit,
      ) async {
    if (state.query.trim().isEmpty) return;

    emit(state.copyWith(isRefreshing: true, clearError: true));

    try {
      final books = await _repo.searchBooks(state.query);
      emit(state.copyWith(
        isRefreshing: false,
        books: books,
      ));
    } catch (e) {
      emit(state.copyWith(
        isRefreshing: false,
        error: 'Ошибка обновления: $e',
      ));
    }
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<IBooksRepository>(
      create: (_) => OpenLibraryBooksRepository(),
      child: BlocProvider(
        create: (ctx) => BooksBloc(ctx.read<IBooksRepository>()),
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BooksSearchPage(),
        ),
      ),
    );
  }
}

class BooksSearchPage extends StatefulWidget {
  const BooksSearchPage({super.key});

  @override
  State<BooksSearchPage> createState() => _BooksSearchPageState();
}

class _BooksSearchPageState extends State<BooksSearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onRefresh(BuildContext context) async {
    context.read<BooksBloc>().add(const BooksRefreshRequested());

    await context.read<BooksBloc>().stream.firstWhere((s) => !s.isRefreshing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Лаба 6 — BLoC + Debounce')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Поиск (debounce ~450ms)',
                border: OutlineInputBorder(),
              ),
              onChanged: (text) {
                context.read<BooksBloc>().add(BooksQueryChanged(text));
              },
              onSubmitted: (text) {
                context.read<BooksBloc>().add(BooksQueryChanged(text));
              },
            ),
            const SizedBox(height: 12),
            BlocBuilder<BooksBloc, BooksState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const LinearProgressIndicator();
                }
                if (state.error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<BooksBloc, BooksState>(
                builder: (context, state) {
                  return RefreshIndicator(
                    onRefresh: () => _onRefresh(context),
                    child: state.books.isEmpty
                        ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Введите запрос, результаты появятся ниже.')),
                      ],
                    )
                        : ListView.builder(
                      itemCount: state.books.length,
                      itemBuilder: (context, index) {
                        final book = state.books[index];
                        return Card(
                          child: ListTile(
                            leading: _CoverImage(url: book.coverUrl),
                            title: Text(book.title),
                            subtitle: Text(
                              'Автор: ${book.author ?? "не указан"}\n'
                                  'Год: ${book.firstPublishYear?.toString() ?? "—"}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
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
      return const SizedBox(width: 48, height: 64, child: Icon(Icons.menu_book));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url!,
        width: 48,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
        const SizedBox(width: 48, height: 64, child: Icon(Icons.broken_image)),
      ),
    );
  }
}
