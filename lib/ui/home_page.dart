import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/utils/debounce.dart';
import 'details_page.dart';
import '../bloc/bloc.dart';
import '../bloc/events.dart';
import '../bloc/state.dart';
import '../domain/models/card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _navToDetails(BuildContext context, data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailsPage(data: data),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final searchController = TextEditingController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeBloc>().add(const HomeLoadDataEvent());
    });
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    context.read<HomeBloc>().add(HomeLoadDataEvent(search: searchController.text));
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listenWhen: (prev, next) => next.snackMessage != null && next.snackMessage != prev.snackMessage,
      listener: (context, state) {
        final msg = state.snackMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(msg)));
          context.read<HomeBloc>().add(const HomeClearSnackEvent());
        }
      },
      builder: (context, state) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: CupertinoSearchTextField(
                  controller: searchController,
                  onChanged: (search) {
                    Debounce.run(() {
                      context.read<HomeBloc>().add(HomeLoadDataEvent(search: search));
                    });
                  },
                ),
              ),
              if (state.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: state.data.length,
                      itemBuilder: (context, index) {
                        final data = state.data[index];

                        return PersonCard(
                          data: data,
                          onLike: (title, isLiked) {
                            context.read<HomeBloc>().add(HomeToggleLikeEvent(data.id));

                          },
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => DetailsPage(data: data)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
