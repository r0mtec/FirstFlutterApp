import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'l10n/app_localizations.dart';

void main() {
  runApp(const AppRoot());
}


class BookDto extends Equatable {
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
      title: (json['title'] ?? 'Untitled').toString(),
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

  @override
  List<Object?> get props => [title, author, firstPublishYear, coverId];
}


abstract class IBooksRepository {
  Future<List<BookDto>> searchBooks(String query);
}

class OpenLibraryBooksRepository implements IBooksRepository {
  final http.Client _client;
  OpenLibraryBooksRepository({http.Client? client}) : _client = client ?? http.Client();

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

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = data['docs'];
    if (docs is! List) return <BookDto>[];

    return docs
        .take(20)
        .whereType<Map<String, dynamic>>()
        .map(BookDto.fromJson)
        .toList(growable: false);
  }
}

class AppDatabase {
  static const _dbName = 'lab7.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
					CREATE TABLE favorites(
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						title TEXT NOT NULL,
						author TEXT,
						year INTEGER,
						coverId INTEGER
					);
				''');

        await db.execute('''
					CREATE TABLE settings(
						key TEXT PRIMARY KEY,
						value TEXT NOT NULL
					);
				''');
      },
    );

    _db = db;
    return db;
  }
}

abstract class IFavoritesRepository {
  Future<Set<String>> getFavoriteKeys();
  Future<void> add(BookDto book);
  Future<void> remove(BookDto book);
  Future<List<BookDto>> getAll();
}

class FavoritesRepository implements IFavoritesRepository {
  final AppDatabase _database;
  FavoritesRepository(this._database);

  String _key(BookDto b) => '${b.title}__${b.author ?? ""}__${b.firstPublishYear ?? ""}__${b.coverId ?? ""}';

  @override
  Future<Set<String>> getFavoriteKeys() async {
    final db = await _database.database;
    final rows = await db.query('favorites');
    return rows.map((r) {
      final title = (r['title'] ?? '').toString();
      final author = (r['author'] ?? '').toString();
      final year = (r['year'] ?? '').toString();
      final coverId = (r['coverId'] ?? '').toString();
      return '${title}__${author}__${year}__${coverId}';
    }).toSet();
  }

  @override
  Future<void> add(BookDto book) async {
    final db = await _database.database;
    await db.insert('favorites', {
      'title': book.title,
      'author': book.author,
      'year': book.firstPublishYear,
      'coverId': book.coverId,
    });
  }

  @override
  Future<void> remove(BookDto book) async {
    final db = await _database.database;
    await db.delete(
      'favorites',
      where: 'title = ? AND author IS ? AND year IS ? AND coverId IS ?',
      whereArgs: [book.title, book.author, book.firstPublishYear, book.coverId],
    );
  }

  @override
  Future<List<BookDto>> getAll() async {
    final db = await _database.database;
    final rows = await db.query('favorites', orderBy: 'id DESC');
    return rows.map((r) {
      return BookDto(
        title: (r['title'] ?? '').toString(),
        author: r['author']?.toString(),
        firstPublishYear: r['year'] as int?,
        coverId: r['coverId'] as int?,
      );
    }).toList(growable: false);
  }

  bool isFavorite(Set<String> keys, BookDto book) => keys.contains(_key(book));
  String keyOf(BookDto book) => _key(book);
}

abstract class ISettingsRepository {
  Future<String?> getValue(String key);
  Future<void> setValue(String key, String value);
}

class SettingsRepository implements ISettingsRepository {
  final AppDatabase _database;
  SettingsRepository(this._database);

  @override
  Future<String?> getValue(String key) async {
    final db = await _database.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  @override
  Future<void> setValue(String key, String value) async {
    final db = await _database.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

class BooksBloc extends Bloc<BooksEvent, BooksState> {
  final IBooksRepository _repo;
  Timer? _debounce;

  BooksBloc(this._repo) : super(BooksState.initial()) {
    on<BooksQueryChanged>(_onQueryChanged);
    on<BooksRefreshRequested>(_onRefresh);
  }

  Future<void> _onQueryChanged(BooksQueryChanged event, Emitter<BooksState> emit) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      emit(state.copyWith(query: event.query, isLoading: true, clearError: true));
      try {
        final books = await _repo.searchBooks(event.query);
        emit(state.copyWith(isLoading: false, books: books));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });
  }

  Future<void> _onRefresh(BooksRefreshRequested event, Emitter<BooksState> emit) async {
    if (state.query.trim().isEmpty) return;
    emit(state.copyWith(isRefreshing: true, clearError: true));
    try {
      final books = await _repo.searchBooks(state.query);
      emit(state.copyWith(isRefreshing: false, books: books));
    } catch (e) {
      emit(state.copyWith(isRefreshing: false, error: e.toString()));
    }
  }
}


class FavoritesState extends Equatable {
  final Set<String> favoriteKeys;
  final List<BookDto> favorites;

  const FavoritesState({required this.favoriteKeys, required this.favorites});

  factory FavoritesState.initial() => const FavoritesState(favoriteKeys: <String>{}, favorites: <BookDto>[]);

  @override
  List<Object?> get props => [favoriteKeys, favorites];
}

class FavoritesCubit extends Cubit<FavoritesState> {
  final FavoritesRepository _repo;

  FavoritesCubit(this._repo) : super(FavoritesState.initial());

  Future<void> load() async {
    final keys = await _repo.getFavoriteKeys();
    final favs = await _repo.getAll();
    emit(FavoritesState(favoriteKeys: keys, favorites: favs));
  }

  Future<void> toggle(BookDto book) async {
    final key = _repo.keyOf(book);
    final isFav = state.favoriteKeys.contains(key);

    if (isFav) {
      await _repo.remove(book);
    } else {
      await _repo.add(book);
    }
    await load();
  }

  bool isFavorite(BookDto book) => state.favoriteKeys.contains(_repo.keyOf(book));
}


class LocaleCubit extends Cubit<Locale> {
  final ISettingsRepository _settings;

  LocaleCubit(this._settings) : super(const Locale('ru'));

  Future<void> load() async {
    final value = await _settings.getValue('locale');
    if (value == 'en') emit(const Locale('en'));
    if (value == 'ru') emit(const Locale('ru'));
  }

  Future<void> setLocale(Locale locale) async {
    emit(locale);
    await _settings.setValue('locale', locale.languageCode);
  }
}


class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<IBooksRepository>(create: (_) => OpenLibraryBooksRepository()),
        RepositoryProvider<AppDatabase>(create: (_) => db),
        RepositoryProvider<FavoritesRepository>(create: (_) => FavoritesRepository(db)),
        RepositoryProvider<ISettingsRepository>(create: (_) => SettingsRepository(db)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => BooksBloc(ctx.read<IBooksRepository>())),
          BlocProvider(
            create: (ctx) => FavoritesCubit(ctx.read<FavoritesRepository>())..load(),
          ),
          BlocProvider(
            create: (ctx) => LocaleCubit(ctx.read<ISettingsRepository>())..load(),
          ),
        ],
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: locale,
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const BooksPage(),
            );
          },
        ),
      ),
    );
  }
}


class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    context.read<BooksBloc>().add(const BooksRefreshRequested());
    await context.read<BooksBloc>().stream.firstWhere((s) => !s.isRefreshing);
  }

  void _toggleLang() {
    final current = context.read<LocaleCubit>().state.languageCode;
    context.read<LocaleCubit>().setLocale(current == 'ru' ? const Locale('en') : const Locale('ru'));
  }

  void _openFavorites() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr.appTitle),
        actions: [
          IconButton(onPressed: _openFavorites, icon: const Icon(Icons.favorite)),
          IconButton(onPressed: _toggleLang, icon: const Icon(Icons.language)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) => context.read<BooksBloc>().add(BooksQueryChanged(v)),
                    decoration: InputDecoration(
                      labelText: tr.searchHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => context.read<BooksBloc>().add(BooksQueryChanged(_controller.text)),
                  child: Text(tr.searchButton),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: BlocBuilder<BooksBloc, BooksState>(
                builder: (context, state) {
                  if (state.isLoading) return const Center(child: CircularProgressIndicator());

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: state.books.isEmpty
                        ? ListView(
                      children: [
                        const SizedBox(height: 140),
                        Center(child: Text(tr.pullToRefresh)),
                      ],
                    )
                        : ListView.builder(
                      itemCount: state.books.length,
                      itemBuilder: (context, index) {
                        final book = state.books[index];

                        return BlocBuilder<FavoritesCubit, FavoritesState>(
                          builder: (context, favState) {
                            final isFav = context.read<FavoritesCubit>().isFavorite(book);

                            return Card(
                              child: ListTile(
                                leading: _CoverImage(url: book.coverUrl),
                                title: Text(book.title),
                                subtitle: Text(
                                  '${book.author ?? "—"} • ${book.firstPublishYear?.toString() ?? "—"}',
                                ),
                                trailing: IconButton(
                                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                                  onPressed: () async {
                                    await context.read<FavoritesCubit>().toggle(book);

                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isFav ? tr.removedFromFav : tr.addedToFav),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
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

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(tr.favorites)),
      body: BlocBuilder<FavoritesCubit, FavoritesState>(
        builder: (context, state) {
          if (state.favorites.isEmpty) {
            return const Center(child: Text('—'));
          }
          return ListView.builder(
            itemCount: state.favorites.length,
            itemBuilder: (context, index) {
              final book = state.favorites[index];
              return Card(
                child: ListTile(
                  leading: _CoverImage(url: book.coverUrl),
                  title: Text(book.title),
                  subtitle: Text('${book.author ?? "—"} • ${book.firstPublishYear?.toString() ?? "—"}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String? url;
  const _CoverImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox(width: 48, height: 64, child: Icon(Icons.menu_book));

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url!,
        width: 48,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 64, child: Icon(Icons.broken_image)),
      ),
    );
  }
}
