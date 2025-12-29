import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:lab/data/dtos/books_dto.dart';
import 'package:lab/data/mappers/books_mapper.dart';
import 'package:lab/data/repositories/api_interface.dart';
import 'package:lab/domain/models/card.dart';

class OpenLibraryRepository extends ApiInterface {
  static final Dio _dio = Dio()
    ..interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: false,
        responseHeader: false,
      ),
    );

  static const String _baseUrl = 'https://openlibrary.org';

  @override
  Future<List<CardData>?> loadData(String query) async {
    try {
      final String url = '$_baseUrl/search.json';

      final Response<dynamic> response = await _dio.get<dynamic>(
        url,
        queryParameters: {'q': query},
      );

      final dto = BooksDto.fromJson(response.data as Map<String, dynamic>);
      final List<CardData>? data =
      dto.data?.map((e) => e.toDomain()).toList();

      return data;
    } on DioException catch (_) {
      // todo show error
      return null;
    } catch (_) {
      return null;
    }
  }
}
