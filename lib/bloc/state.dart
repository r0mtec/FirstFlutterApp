import 'package:equatable/equatable.dart';

import '../domain/models/card_data.dart';

class HomeState extends Equatable {
  final List<CardData> data;
  final bool isLoading;

  final String? snackMessage;

  const HomeState({
    this.data = const [],
    this.isLoading = false,
    this.snackMessage,
  });

  HomeState copyWith({
    List<CardData>? data,
    bool? isLoading,
    String? snackMessage,
  }) {
    return HomeState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      snackMessage: snackMessage,
    );
  }

  @override
  List<Object?> get props => [data, isLoading, snackMessage];
}
