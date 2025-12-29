import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/cards_repository.dart';
import '../domain/models/card_data.dart';
import 'events.dart';
import 'state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final CardsRepository repo;

  HomeBloc(this.repo) : super(const HomeState()) {
    on<HomeLoadDataEvent>(_onLoadData);
    on<HomeToggleLikeEvent>(_onToggleLike);
    on<HomeClearSnackEvent>(_onClearSnack);
  }

  Future<void> _onLoadData(HomeLoadDataEvent event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      final List<CardData> items = await repo.loadData(
        q: event.search,
        currentStateData: state.data,
      );

      emit(state.copyWith(
        isLoading: false,
        data: items,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        snackMessage: 'Ошибка загрузки: $e',
      ));
    }
  }

  void _onToggleLike(HomeToggleLikeEvent event, Emitter<HomeState> emit) {
    final updated = state.data.map((x) {
      if (x.id != event.id) return x;
      return x.copyWith(isLiked: !x.isLiked);
    }).toList();

    final item = updated.firstWhere((x) => x.id == event.id);

    emit(state.copyWith(
      data: updated,
      snackMessage: item.isLiked ? 'Лайк поставлен: ${item.title}' : 'Лайк убран: ${item.title}',
    ));
  }

  void _onClearSnack(HomeClearSnackEvent event, Emitter<HomeState> emit) {
    emit(state.copyWith(snackMessage: null));
  }
}
