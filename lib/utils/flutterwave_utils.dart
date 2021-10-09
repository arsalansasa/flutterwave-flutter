import 'package:flutterwave/core/flutterwave_error.dart';
import 'package:flutterwave/models/francophone_country.dart';
import 'package:flutterwave/utils/flutterwave_currency.dart';
import 'package:tripledes_nullsafety/tripledes_nullsafety.dart';

class FlutterwaveUtils {
  static putIfNotNull(Map map, String key, String? value) {
    if (value == null || value is String && value.isEmpty) return;
    map[key] = value;
  }

  /// Encrypts data using 3DES technology.
  /// Returns a String
  static String tripleDESEncrypt(dynamic data, String encryptionKey) {
    try {
      final blockCipher = BlockCipher(TripleDESEngine(), encryptionKey);
      return blockCipher.encodeB64(data);
    } catch (error) {
      throw (FlutterWaveError("Unable to encrypt request: $error"));
    }
  }

  /// Creates a card request with encrypted details
  /// Returns a map.
  static Map<String, String> createCardRequest(String encryptedData) {
    return {"client": encryptedData};
  }

  /// Returns a list of francophone countries by their currencies
  static List<FrancoPhoneCountry> getFrancoPhoneCountries(
      final String currency) {
    if (currency == FlutterwaveCurrency.XAF)
      return [FrancoPhoneCountry("CAMEROON", "CM")];
    return [
      FrancoPhoneCountry("BURKINA FASO", "BF"),
      FrancoPhoneCountry("COTE D'IVOIRE", "CI"),
      FrancoPhoneCountry("GUINEA", "GN"),
      FrancoPhoneCountry("SENEGAL", "SN"),
    ];
  }
}
