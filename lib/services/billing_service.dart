import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/network.dart';
import 'package:photos/models/billing_plan.dart';
import 'package:photos/models/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillingService {
  BillingService._privateConstructor() {}

  static final BillingService instance = BillingService._privateConstructor();
  static const subscriptionKey = "subscription";

  final _logger = Logger("BillingService");
  final _dio = Network.instance.getDio();
  final _config = Configuration.instance;

  SharedPreferences _prefs;
  Future<List<BillingPlan>> _future;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<BillingPlan>> getBillingPlans() {
    if (_future == null) {
      _future = _dio
          .get(_config.getHttpEndpoint() + "/billing/plans")
          .then((response) {
        final plans = List<BillingPlan>();
        for (final plan in response.data["plans"]) {
          plans.add(BillingPlan.fromMap(plan));
        }
        return plans;
      });
    }
    return _future;
  }

  Future<Subscription> loadSubscription(String verificationData) async {
    return _dio
        .get(
      _config.getHttpEndpoint() + "/billing/subscription",
      queryParameters: {
        "client": Platform.isAndroid ? "android" : "ios",
        "verificationData": verificationData,
      },
      options: Options(
        headers: {
          "X-Auth-Token": _config.getToken(),
        },
      ),
    )
        .then((response) {
      if (response == null || response.statusCode != 200) {
        throw Exception(response);
      }
      final subscription = Subscription.fromMap(response.data["subscription"]);
      setSubscription(subscription);
      return subscription;
    });
  }

  // TODO: Fetch new subscription once the current one has expired?
  Subscription getSubscription() {
    final jsonValue = _prefs.getString(subscriptionKey);
    if (jsonValue == null) {
      return null;
    } else {
      return Subscription.fromJson(jsonValue);
    }
  }

  bool hasActiveSubscription() {
    final subscription = getSubscription();
    return subscription != null &&
        subscription.validTill > DateTime.now().microsecondsSinceEpoch;
  }

  Future<void> setSubscription(Subscription subscription) async {
    await _prefs.setString(
        subscriptionKey, subscription == null ? null : subscription.toJson());
  }
}
