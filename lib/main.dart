import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:lab/bloc/bloc.dart';
import 'package:lab/data/repositories/api_interface.dart';
import 'package:lab/data/repositories/cards_repository.dart';
import 'package:lab/data/repositories/openlibrary_repository.dart';
import 'package:lab/ui/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab6',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
      ),
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ApiInterface>(
            create: (_) => OpenLibraryRepository(),
          ),
          RepositoryProvider<CardsRepository>(
            create: (context) => CardsRepository(context.read<ApiInterface>()),
          ),
        ],
        child: BlocProvider<HomeBloc>(
          lazy: false,
          create: (context) => HomeBloc(context.read<CardsRepository>()),
          child: const HomePage(),
        ),
      ),
    );
  }
}
