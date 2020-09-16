import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutterwave/models/requests/voucher/voucher_payment_request.dart';
import 'package:flutterwave/models/responses/charge_response.dart';
import 'package:flutterwave/utils/flutterwave_utils.dart';

import 'package:http/http.dart' as http;

class VoucherPaymentManager {
  String publicKey;
  String currency;
  String amount;
  String txRef;
  bool isDebugMode;
  String phoneNumber;
  String fullName;
  String email;

  VoucherPaymentManager({
    @required this.publicKey,
    @required this.isDebugMode,
    @required this.amount,
    @required this.currency,
    @required this.email,
    @required this.txRef,
    @required this.fullName,
    @required this.phoneNumber,
  });

  VoucherPaymentManager.fromJson(Map<String, dynamic> json) {
    this.amount = json['amount'];
    this.currency = json['currency'];
    this.email = json['email'];
    this.txRef = json['tx_ref'];
    this.fullName = json['fullname'];
    this.phoneNumber = json["phone_number"];
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': this.amount,
      'currency': this.currency,
      'email': this.email,
      'tx_ref': this.txRef,
      'fullname': this.fullName,
      'phone_number': this.phoneNumber
    };
  }

  Future<ChargeResponse> payWithVoucher(VoucherPaymentRequest payload,
      http.Client client) async {
    final url = FlutterwaveUtils.getBaseUrl(this.isDebugMode) +
        FlutterwaveUtils.VOUCHER_PAYMENT;

    print("voucher url iss ==> $url");
    try {
      final http.Response response = await client.post(url,
          headers: {HttpHeaders.authorizationHeader: this.publicKey},
          body: payload.toJson());

      ChargeResponse chargeResponse =
      ChargeResponse.fromJson(json.decode(response.body));
      return chargeResponse;
    } catch (error) {
      throw (FlutterError(error.toString()));
    } 
  }
} 