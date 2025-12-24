import 'package:dio/dio.dart';

class Api {
  static final Dio dio = Dio(BaseOptions(
    baseUrl: 'https://cashpoint.deovaze.com/api', // <- CHANGE to your Laravel API base URL
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 15),
    headers: {
      'Accept': 'application/json',
    },
  ));
}
