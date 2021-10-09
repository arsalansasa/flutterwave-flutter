class SubAccount {
  final String id;
  final String transactionSplitRatio;
  final String transactionChargeType;
  final String transactionCharge;

  bool isEmpty(String string) {
    return string == null || string.trim().isEmpty;
  }

  SubAccount(
    this.id,
  )   : this.transactionChargeType = "",
        this.transactionSplitRatio = "",
        this.transactionCharge = "";

  Map<String, String> toJson() {
    var map = {_idKey: id};

    if (!isEmpty(transactionSplitRatio)) {
      map[_ratioKey] = transactionSplitRatio;
    }
    if (!isEmpty(transactionChargeType)) {
      map[_chargeTypeKey] = transactionChargeType;
    }

    if (!isEmpty(transactionCharge)) {
      map[_chargeKey] = transactionCharge;
    }
    return map;
  }
}

const _idKey = 'id';
const _ratioKey = 'transaction_split_ratio';
const _chargeTypeKey = 'transaction_charge_type';
const _chargeKey = 'transaction_charge';
