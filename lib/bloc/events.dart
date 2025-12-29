import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeLoadDataEvent extends HomeEvent {
  final String? search;

  const HomeLoadDataEvent({this.search});

  @override
  List<Object?> get props => [search];
}

class HomeToggleLikeEvent extends HomeEvent {
  final int id;

  const HomeToggleLikeEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class HomeClearSnackEvent extends HomeEvent {
  const HomeClearSnackEvent();
}
