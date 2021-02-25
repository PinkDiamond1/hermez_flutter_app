import 'dart:collection';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermez/context/wallet/wallet_handler.dart';
import 'package:hermez/model/wallet.dart';
import 'package:hermez/utils/hermez_colors.dart';
import 'package:hermez/wallet_transfer_amount_page.dart';
import 'package:hermez_plugin/model/account.dart';
import 'package:hermez_plugin/model/forged_transaction.dart';
import 'package:intl/intl.dart';

import '../../wallet_transaction_details_page.dart';

class ActivityArguments {
  final WalletHandler store;
  final Account account;
  final String address;
  final String symbol;
  final double exchangeRate;
  final WalletDefaultCurrency defaultCurrency;

  ActivityArguments(this.store, this.account, this.address, this.symbol,
      this.exchangeRate, this.defaultCurrency);
}

class Activity extends StatefulWidget {
  Activity({Key key, this.arguments}) : super(key: key);

  final ActivityArguments arguments;

  @override
  _ActivityState createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: fetchTransactions(),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.white,
            child: Center(
              child: CircularProgressIndicator(
                backgroundColor: HermezColors.orange,
              ),
            ),
          );
        } else {
          if (snapshot.hasError) {
            // while data is loading:
            return Container(
              color: Colors.white,
              child: Center(
                child: Text('There was an error:' + snapshot.error.toString()),
              ),
            );
          } else {
            if (snapshot.hasData && snapshot.data.length > 0) {
              return buildActivityList(snapshot.data);
            } else {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.only(
                      left: 60.0, right: 60.0, top: 50.0, bottom: 50.0),
                  color: Colors.white,
                  child: Text(
                    'Account transactions will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HermezColors.blueyGrey,
                      fontSize: 16,
                      fontFamily: 'ModernEra',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
          }
        }
      },
    );
  }

  //widget that builds the list
  Widget buildActivityList(List<dynamic> dataList) {
    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: dataList.length,
          //set the item count so that index won't be out of range
          padding: const EdgeInsets.all(16.0),
          //add some padding to make it look good
          itemBuilder: (context, i) {
            var title = "";
            var subtitle = "";
            dynamic element = dataList.elementAt(i);
            var type = 'type';
            var txType;
            var status = 'status';
            var timestamp = 0;
            var txHash = 'txHash';
            var addressFrom = 'from';
            var addressTo = 'to';
            var value = '0';
            if (element.runtimeType == LinkedHashMap) {
              LinkedHashMap event = element;
              type = event['type'];
              status = event['status'];
              timestamp = event['timestamp'];
              txHash = event['txHash'];
              addressFrom = event['from'];
              addressTo = event['to'];
              value = event['value'];
            } else if (element.runtimeType == ForgedTransaction) {
              ForgedTransaction transaction = element;
              if (transaction.type == "CreateAccountDeposit" ||
                  transaction.type == "Deposit") {
                type = "DEPOSIT";
                value = transaction.l1info.depositAmount.toString();
                if (transaction.l1info.depositAmountSuccess == true) {
                  status = "CONFIRMED";
                }
              } else if (transaction.type == "Exit" ||
                  transaction.type == "ForceExit") {
                type = "WITHDRAW";
                value = transaction.amount.toString();
              } else if (transaction.type == "Transfer") {
                value = transaction.amount.toString();
                if (transaction.fromAccountIndex ==
                    widget.arguments.account.accountIndex) {
                  type = "SEND";
                } else if (transaction.toAccountIndex ==
                    widget.arguments.account.accountIndex) {
                  type = "RECEIVE";
                }
              } else {
                txHash = transaction.id;
              }
              txHash = transaction.id;
            }
            final String currency =
                widget.arguments.defaultCurrency.toString().split('.').last;

            var amount = double.parse(value) / pow(10, 18);
            /*EtherAmount.fromUnitAndValue(
                  EtherUnit.wei, ));*/
            var date = new DateTime.fromMillisecondsSinceEpoch(timestamp);
            var format = DateFormat('dd MMM');
            var icon = "";
            var isNegative = false;

            switch (type) {
              case "RECEIVE":
                txType = TransactionType.RECEIVE;
                title = "Received";
                icon = "assets/tx_receive.png";
                isNegative = false;
                break;
              case "SEND":
                txType = TransactionType.SEND;
                title = "Sent";
                icon = "assets/tx_send.png";
                isNegative = true;
                break;
              case "WITHDRAW":
                txType = TransactionType.WITHDRAW;
                title = "Withdrawn";
                icon = "assets/tx_withdraw.png";
                isNegative = true;
                break;
              case "DEPOSIT":
                txType = TransactionType.DEPOSIT;
                title = "Deposited";
                icon = "assets/tx_deposit.png";
                isNegative = false;
                break;
            }

            if (status == "CONFIRMED") {
              subtitle = format.format(date);
            }

            return Container(
              child: ListTile(
                leading: _getLeadingWidget(
                    icon,
                    //element['status'] == 'invalid'
                    /*? Color.fromRGBO(255, 239, 241, 1.0)
                          :*/
                    /*Colors.grey[100]*/ null),
                title: Container(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: HermezColors.black,
                      fontSize: 16,
                      fontFamily: 'ModernEra',
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                subtitle: Container(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HermezColors.blueyGreyTwo,
                      fontSize: 16,
                      fontFamily: 'ModernEra',
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        //color: double.parse(element['value']) < 0 ? Colors.transparent : Color.fromRGBO(228, 244, 235, 1.0),
                        padding: EdgeInsets.all(5.0),
                        child: Text(
                          (isNegative ? "- " : "") +
                              (currency == "USD" ? "\$" : "€") +
                              (widget.arguments.exchangeRate * amount)
                                  .toStringAsFixed(2),
                          style: TextStyle(
                            color: isNegative
                                ? HermezColors.black
                                : HermezColors.green,
                            fontSize: 16,
                            fontFamily: 'ModernEra',
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(5.0),
                        child: Text(
                          amount.toString() + " " + widget.arguments.symbol,
                          style: TextStyle(
                            color: HermezColors.blueyGreyTwo,
                            fontSize: 16,
                            fontFamily: 'ModernEra',
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ]),
                onTap: () async {
                  Navigator.pushNamed(context, "/transaction_details",
                      arguments: TransactionDetailsArguments(
                          wallet: widget.arguments.store,
                          transactionType: txType,
                          status: TransactionStatus.CONFIRMED,
                          account: widget.arguments.account,
                          /*widget.arguments.store,
                            widget.arguments.amountType,
                            widget.arguments.account,*/
                          amount: amount,
                          transactionHash: txHash,
                          addressFrom: addressFrom,
                          addressTo: addressTo,
                          transactionDate: date));
                },
              ),
            );
          },
        ),
        onRefresh: _onRefresh,
      ),
    );
  }

  Future<void> _onRefresh() async {
    // monitor network fetch
    await Future.delayed(Duration(milliseconds: 1000));

    setState(() {
      fetchTransactions();
    });
    // if failed,use refreshFailed()
    //_elements = widget.arguments.cryptoList;
    //_refreshController.refreshCompleted();
  }

  Future<List<dynamic>> fetchTransactions() async {
    return await widget.arguments.store.getTransactionsByAddress(
        widget.arguments.store.state.ethereumAddress, widget.arguments.account);
  }

  // takes in an object and color and returns a circle avatar with first letter and required color
  CircleAvatar _getLeadingWidget(String icon, Color color) {
    return new CircleAvatar(
        radius: 23, backgroundColor: color, child: Image.asset(icon));
  }
}
