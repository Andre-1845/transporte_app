class AppConfig {
  // true = produção (Hostinger)
  // false = desenvolvimento local
  static const bool production = true;

  static const String localApi = "http://10.0.2.2:8000/api/v1";

  static const String productionApi =
      "https://aliceblue-manatee-511810.hostingersite.com/api/v1";

  static String get apiUrl {
    return production ? productionApi : localApi;
  }
}
