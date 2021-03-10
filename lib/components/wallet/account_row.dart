import 'package:flutter/material.dart';
import 'package:hermez/utils/hermez_colors.dart';
import 'package:intl/intl.dart';

class AccountRow extends StatelessWidget {
  AccountRow(this.name, this.symbol, this.price, this.defaultCurrency,
      this.amount, this.simplified, this.currencyFirst, this.onPressed);

  final String name;
  final String symbol;
  final double price;
  final String defaultCurrency;
  final double amount;
  final bool simplified;
  final bool currencyFirst;
  final void Function(String token, String amount) onPressed;

  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.only(bottom: 15.0),
        child: FlatButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: HermezColors.lightGrey)),
          onPressed: () {
            this.onPressed(
              symbol,
              amount.toString(),
            );
          },
          padding: EdgeInsets.all(20.0),
          color: HermezColors.lightGrey,
          textColor: Colors.black,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        simplified ? this.name : this.symbol,
                        style: TextStyle(
                          color: HermezColors.blackTwo,
                          fontSize: 16,
                          fontFamily: 'ModernEra',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    simplified
                        ? Container()
                        : Container(
                            padding: EdgeInsets.only(top: 15.0),
                            alignment: Alignment.centerLeft,
                            child: Text(this.name,
                                style: TextStyle(
                                  color: HermezColors.blueyGreyTwo,
                                  fontFamily: 'ModernEra',
                                  fontWeight: FontWeight.w500,
                                )),
                          ),
                  ],
                ),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      child: Text(
                        simplified
                            ? formatAmount(
                                currencyFirst
                                    ? (this.price * this.amount)
                                    : this.amount,
                                currencyFirst ? defaultCurrency : this.symbol)
                            : formatAmount(
                                currencyFirst ? this.amount : this.price,
                                this.symbol),
                        style: TextStyle(
                            fontFamily: 'ModernEra',
                            fontWeight: FontWeight.w600,
                            color: HermezColors.blackTwo,
                            fontSize: 16),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    simplified
                        ? Container()
                        : Container(
                            padding: EdgeInsets.only(top: 15.0),
                            child: Text(
                              formatAmount(
                                  currencyFirst
                                      ? (this.price * this.amount)
                                      : this.amount,
                                  currencyFirst
                                      ? defaultCurrency
                                      : this.symbol),
                              style: TextStyle(
                                fontFamily: 'ModernEra',
                                fontWeight: FontWeight.w500,
                                color: HermezColors.blueyGreyTwo,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                  ]),
            ],
          ), //title to be name of the crypto
        ));
  }

  String formatAmount(double amount, String symbol) {
    double resultValue = 0;
    String result = "";
    String locale = "eu";
    if (symbol == "EUR") {
      locale = 'eu';
      symbol = '€';
    } else if (symbol == "USD") {
      locale = 'en';
      symbol = '\$';
    }
    if (amount != null) {
      double value = amount;
      resultValue = resultValue + value;
    }
    result =
        NumberFormat.currency(locale: locale, symbol: symbol).format(amount);
    return result;
  }
}
