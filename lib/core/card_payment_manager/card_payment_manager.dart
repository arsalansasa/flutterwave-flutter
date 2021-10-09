import 'dart:convert';
import 'dart:io';

import 'package:flutterwave/core/core_utils/flutterwave_api_utils.dart';
import 'package:flutterwave/core/metrics/metric_manager.dart';
import 'package:flutterwave/interfaces/card_payment_listener.dart';
import 'package:flutterwave/models/requests/SubAccount.dart';
import 'package:flutterwave/models/requests/authorization.dart';
import 'package:flutterwave/models/requests/charge_card/charge_card_request.dart';
import 'package:flutterwave/models/requests/charge_card/charge_request_address.dart';
import 'package:flutterwave/models/responses/charge_response.dart';
import 'package:flutterwave/utils/flutterwave_constants.dart';
import 'package:flutterwave/utils/flutterwave_urls.dart';
import 'package:flutterwave/utils/flutterwave_utils.dart';
import 'package:http/http.dart' as http;

class CardPaymentManager {
  String publicKey;
  String encryptionKey;
  String currency;
  String amount;
  String email;
  String fullName;
  String txRef;
  bool isDebugMode;
  String? phoneNumber;
  int? frequency;
  int? duration;
  bool? isPermanent;
  String? narration;
  String? country;
  String? redirectUrl;
  List<SubAccount>? subaccounts;

  late ChargeCardRequest chargeCardRequest;
  CardPaymentListener? cardPaymentListener;
  Stopwatch _stopwatch = Stopwatch();

  /// CardPaymentManager constructor
  CardPaymentManager(
      {required this.publicKey,
      required this.encryptionKey,
      required this.currency,
      required this.amount,
      required this.email,
      required this.fullName,
      required this.txRef,
      required this.isDebugMode,
      this.subaccounts,
      this.country,
      this.phoneNumber,
      this.frequency,
      this.duration,
      this.isPermanent,
      this.narration,
      this.redirectUrl});

  /// This method is required to add a payment listener to card transactions
  CardPaymentManager setCardPaymentListener(
      final CardPaymentListener cardPaymentListener) {
    this.cardPaymentListener = cardPaymentListener;
    return this;
  }

  /// Responsible for encrypting charge requests using 3DES encryption
  /// it returns a map
  Map<String, String> _prepareRequest(
      final ChargeCardRequest chargeCardRequest) {
    var body = chargeCardRequest.toJson();
    FlutterwaveUtils.putIfNotNull(
        body,
        'subaccounts',
        subaccounts == null || subaccounts!.isEmpty
            ? null
            : subaccounts!.map((a) => a.toJson()).toList());

    final String encryptedChargeRequest =
        FlutterwaveUtils.tripleDESEncrypt(jsonEncode(body), encryptionKey);
    return FlutterwaveUtils.createCardRequest(encryptedChargeRequest);
  }

  /// Initiates Card Request
  Future<dynamic> payWithCard(final http.Client client,
      final ChargeCardRequest chargeCardRequest) async {
    this.chargeCardRequest = chargeCardRequest;

    if (this.cardPaymentListener == null) {
      this.cardPaymentListener!.onError("No CardPaymentListener Attached.");
      return;
    }
    _stopwatch.start();

    Map<String, String> encryptedPayload;

    try {
      encryptedPayload = this._prepareRequest(chargeCardRequest);
    } catch (error, stacktrace) {
      print(stacktrace);
      this
          .cardPaymentListener
          ?.onError("Unable to encrypt request. Please try again");
      return;
    }

    try {
      final url = FlutterwaveURLS.getBaseUrl(this.isDebugMode) +
          FlutterwaveURLS.CHARGE_CARD_URL;
      final uri = Uri.parse(url);

      final http.Response response = await client.post(uri,
          headers: {
            HttpHeaders.authorizationHeader: this.publicKey,
            HttpHeaders.contentTypeHeader: "application/json"
          },
          body: jsonEncode(encryptedPayload));

      this._handleResponse(response);
    } catch (error, stacktrace) {
      print(stacktrace);
      this.cardPaymentListener?.onError("Unable to initiate card transaction.");
      return;
    } finally {
      _stopwatch.stop();
    }
  }

  /// Responsible for vhandling card payment responses depending on
  /// the card's authorization mode.
  /// It calls the Callback methods when it required additional information
  /// for authorisation
  void _handleResponse(final http.Response response) {
    try {
      final responseBody = ChargeResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode == 200) {
        MetricManager.logMetric(
            http.Client(),
            this.publicKey,
            MetricManager.INITIATE_CARD_CHARGE,
            "${_stopwatch.elapsedMilliseconds}ms");
        _stopwatch.reset();

        if (responseBody.status == FlutterwaveConstants.SUCCESS &&
            responseBody.data != null &&
            (responseBody.data!.status == FlutterwaveConstants.SUCCESSFUL ||
                responseBody.data!.status == FlutterwaveConstants.SUCCESS) &&
            responseBody.data!.txRef == this.txRef &&
            responseBody.data!.amount == this.amount) {
          return this.cardPaymentListener?.onNoAuthRequired(responseBody);
        }

        final bool requiresExtraAuth =
            (responseBody.message == FlutterwaveConstants.REQUIRES_AUTH) &&
                (responseBody.meta?.authorization?.mode != null);

        final bool is3DS = (responseBody.message ==
                FlutterwaveConstants.CHARGE_INITIATED) &&
            (responseBody.meta?.authorization?.mode == Authorization.REDIRECT);

        final bool requiresOtp =
            (responseBody.message == FlutterwaveConstants.CHARGE_INITIATED) &&
                (responseBody.meta?.authorization?.mode == Authorization.OTP);

        if (requiresExtraAuth) {
          return this
              ._handleExtraCardAuth(responseBody, this.cardPaymentListener);
        }
        if (is3DS) {
          final redirectUrl = responseBody.meta?.authorization?.redirect;
          if (redirectUrl != null) {
            return this
                .cardPaymentListener
                ?.onRedirect(responseBody, redirectUrl);
          }
          return this.cardPaymentListener?.onError(
              "Unable to complete payment. 3DS auth model detected but no redirect_url provided.");
        }
        if (requiresOtp) {
          return this.cardPaymentListener?.onRequireOTP(
              responseBody, responseBody.data!.processorResponse!);
        }

        MetricManager.logMetric(
            http.Client(),
            this.publicKey,
            MetricManager.INITIATE_CARD_CHARGE_ERROR,
            "${_stopwatch.elapsedMilliseconds}ms");
        _stopwatch.reset();

        return this.cardPaymentListener?.onError(
            "Unable to complete payment. Authorisation mode not specified.");
      }

      if (response.statusCode >= 400) {
        return this.cardPaymentListener?.onError(responseBody.message!);
      }

      return this
          .cardPaymentListener
          ?.onError(jsonDecode(response.body).toString());
    } catch (e, stacktrace) {
      print(stacktrace);
      this.cardPaymentListener?.onError(e.toString());
    }
  }

  /// This method is responsible for handling further card authentication
  void _handleExtraCardAuth(
      ChargeResponse response, CardPaymentListener? listener) {
    final authMode = response.meta?.authorization?.mode;
    if (Authorization.AVS == authMode) {
      return this.cardPaymentListener?.onRequireAddress(response);
    }
    if (Authorization.REDIRECT == authMode) {
      final redirectUrl = response.meta?.authorization?.redirect;
      if (redirectUrl != null) {
        return this.cardPaymentListener?.onRedirect(response, redirectUrl);
      }
      return this.cardPaymentListener?.onError(
          "Unable to complete card charge. redirect url not specified");
    }
    if (Authorization.OTP == authMode) {
      final _authMode = response.data?.processorResponse;
      if (_authMode != null) {
        return this.cardPaymentListener?.onRequireOTP(response, _authMode);
      }
      return this.cardPaymentListener?.onError(
          "Unable to complete card charge. OTP message not specified.");
    }
    if (Authorization.PIN == authMode)
      return this.cardPaymentListener?.onRequirePin(response);
    return this.cardPaymentListener?.onError("Unable to detect card auth mode");
  }

  /// This method is responsible for updating a card request with the card's pin
  Future<dynamic> addPin(String pin) async {
    Authorization auth = Authorization();
    auth.mode = Authorization.PIN;
    auth.pin = pin;
    this.chargeCardRequest.authorization = auth;
    this.payWithCard(http.Client(), this.chargeCardRequest);
  }

  /// This method is responsible for updating a card request with the card's
  /// address information
  Future<dynamic> addAddress(ChargeRequestAddress chargeAddress) async {
    Authorization auth = Authorization();
    auth.mode = Authorization.AVS;
    auth.address = chargeAddress.address;
    auth.city = chargeAddress.city;
    auth.state = chargeAddress.state;
    auth.zipcode = chargeAddress.zipCode;
    auth.country = chargeAddress.country;

    this.chargeCardRequest.authorization = auth;
    this.payWithCard(http.Client(), this.chargeCardRequest);
  }

  /// This method is responsible for updating a card request with the card's OTP
  Future<ChargeResponse> addOTP(String otp, String flwRef) async {
    return FlutterwaveAPIUtils.validatePayment(
        otp,
        flwRef,
        http.Client(),
        this.isDebugMode,
        this.publicKey,
        false,
        MetricManager.VALIDATE_CARD_CHARGE);
  }
}
