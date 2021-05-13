import 'dart:collection';
import 'dart:math';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hermez/components/form/address_input.dart';
import 'package:hermez/components/form/amount_input.dart';
import 'package:hermez/components/form/paper_form.dart';
import 'package:hermez/components/wallet/account_row.dart';
import 'package:hermez/components/wallet/move_row.dart';
import 'package:hermez/model/wallet.dart';
import 'package:hermez/screens/qrcode_scanner.dart';
import 'package:hermez/screens/transaction_details.dart';
import 'package:hermez/service/network/model/gas_price_response.dart';
import 'package:hermez/utils/address_utils.dart';
import 'package:hermez/utils/eth_amount_formatter.dart';
import 'package:hermez/utils/hermez_colors.dart';
import 'package:hermez_plugin/addresses.dart';
import 'package:hermez_plugin/constants.dart';
import 'package:hermez_plugin/environment.dart';
import 'package:hermez_plugin/model/account.dart';
import 'package:hermez_plugin/model/recommended_fee.dart';
import 'package:hermez_plugin/model/state_response.dart';
import 'package:hermez_plugin/model/token.dart';

import '../context/wallet/wallet_handler.dart';
import 'account_selector.dart';
import 'fee_selector.dart';
import 'qrcode.dart';

enum TransactionLevel { LEVEL1, LEVEL2 }

enum TransactionType { DEPOSIT, SEND, RECEIVE, WITHDRAW, EXIT, FORCEEXIT }

enum TransactionStatus { DRAFT, PENDING, CONFIRMED, INVALID }

class TransactionAmountArguments {
  TransactionLevel txLevel;
  TransactionType transactionType;
  Account account;
  Token token;
  final double amount;
  final String addressTo;
  final bool allowChangeLevel;
  final WalletHandler store;

  TransactionAmountArguments(this.store, this.txLevel, this.transactionType,
      {this.account,
      this.token,
      this.amount,
      this.addressTo,
      this.allowChangeLevel});
}

class TransactionAmountPage extends StatefulWidget {
  TransactionAmountPage({Key key, this.arguments}) : super(key: key);

  final TransactionAmountArguments arguments;

  @override
  _TransactionAmountPageState createState() => _TransactionAmountPageState();
}

class _TransactionAmountPageState extends State<TransactionAmountPage>
    with AfterLayoutMixin<TransactionAmountPage> {
  bool needRefresh = true;
  bool amountIsValid = true;
  bool addressIsValid = true;
  bool showEstimatedFees = false;
  bool defaultCurrencySelected;
  Token ethereumToken;
  Account ethereumAccount;
  bool enoughGas;
  LinkedHashMap<String, BigInt> depositGasLimit;
  BigInt gasLimit;
  BigInt withdrawGasLimit;
  WalletDefaultFee selectedFeeSpeed;
  WalletDefaultFee selectedWithdrawFeeSpeed;
  GasPriceResponse gasPriceResponse;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  @override
  Future<void> afterFirstLayout(BuildContext context) {
    if (widget.arguments.transactionType != TransactionType.RECEIVE &&
        widget.arguments.account == null) {
      Navigator.of(context).pushNamed("/account_selector",
          arguments: AccountSelectorArguments(
              widget.arguments.txLevel,
              widget.arguments.transactionType,
              widget.arguments.store, onAccountSelected: (selectedAccount) {
            setState(() {
              amountController.clear();
              needRefresh = true;
              if (selectedAccount != null) {
                widget.arguments.account = selectedAccount;
              }
            });
          }, onTokenSelected: (selectedToken) {
            setState(() {
              amountController.clear();
              needRefresh = true;
              if (selectedToken != null) {
                widget.arguments.token = selectedToken;
              }
            });
          }));
    }
  }

  @override
  void initState() {
    super.initState();
    defaultCurrencySelected = false;
    enoughGas = true;
    if (widget.arguments.amount != null && widget.arguments.amount > 0) {
      amountController.text =
          EthAmountFormatter.removeDecimalZeroFormat(widget.arguments.amount);
    }
    if (widget.arguments.addressTo != null &&
        widget.arguments.addressTo.isNotEmpty) {
      addressController.value =
          TextEditingValue(text: widget.arguments.addressTo);
    }
    needRefresh = true;
    selectedFeeSpeed = widget.arguments.store.state.defaultFee;
    selectedWithdrawFeeSpeed = widget.arguments.store.state.defaultFee;
  }

  @override
  void dispose() {
    amountController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: getAppBar(),
      body: _buildAmountForm(),
    );
  }

  String getTitle() {
    String operation = "amount";
    if (widget.arguments.transactionType == TransactionType.SEND) {
      operation = "send";
    } else if (widget.arguments.transactionType == TransactionType.EXIT ||
        widget.arguments.transactionType == TransactionType.FORCEEXIT ||
        widget.arguments.transactionType == TransactionType.DEPOSIT ||
        widget.arguments.transactionType == TransactionType.WITHDRAW) {
      operation = "move";
    } else if (widget.arguments.transactionType == TransactionType.RECEIVE) {
      operation = "receive";
    }
    return operation;
  }

  Widget getAppBar() {
    String operation = getTitle();
    return AppBar(
      title: widget.arguments.transactionType == TransactionType.RECEIVE
          ? Container(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Text(
                    'Amount',
                    style: TextStyle(
                        fontFamily: 'ModernEra',
                        color: HermezColors.blackTwo,
                        fontWeight: FontWeight.w800,
                        fontSize: 20),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                        color: HermezColors.steel),
                    padding: EdgeInsets.only(
                        left: 12.0, right: 12.0, top: 4, bottom: 4),
                    child: Text(
                      widget.arguments.txLevel == TransactionLevel.LEVEL1
                          ? "L1"
                          : "L2",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontFamily: 'ModernEra',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : new Text(operation[0].toUpperCase() + operation.substring(1),
              style: TextStyle(
                  fontFamily: 'ModernEra',
                  color: HermezColors.blackTwo,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
      centerTitle: true,
      elevation: 0.0,
      actions: <Widget>[
        new IconButton(
          icon: new Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ],
    );
  }

  FutureBuilder _buildAmountForm() {
    return FutureBuilder(
      future: fetchData(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          String feeText = getFeeText(snapshot.connectionState);
          BigInt estimatedFee = getEstimatedFee(); //snapshot.data;
          final String currency = widget.arguments.store.state.defaultCurrency
              .toString()
              .split('.')
              .last;

          return Container(
            padding: EdgeInsets.all(10),
            color: Colors.white,
            child: SingleChildScrollView(
              child: PaperForm(
                actionButtons: <Widget>[
                  Column(
                    children: <Widget>[
                      Container(
                        child: Align(
                          alignment: FractionalOffset.bottomCenter,
                          child: SizedBox(
                            width: double.infinity,
                            child: FlatButton(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100.0),
                              ),
                              onPressed: isButtonEnabled()
                                  ? () {
                                      this.onSubmit(
                                          !defaultCurrencySelected
                                              ? double.parse(
                                                  amountController.value.text)
                                              : double.parse((double.parse(
                                                          amountController
                                                              .value.text) /
                                                      (widget.arguments.account !=
                                                              null
                                                          ? widget.arguments
                                                              .account.token.USD
                                                          : widget.arguments
                                                              .token.USD) *
                                                      (currency != "USD"
                                                          ? widget
                                                              .arguments
                                                              .store
                                                              .state
                                                              .exchangeRatio
                                                          : 1))
                                                  .toStringAsFixed(6)),
                                          widget.arguments.account != null
                                              ? widget.arguments.account.token
                                              : widget.arguments.token,
                                          estimatedFee.toDouble(),
                                          widget.arguments.txLevel ==
                                                  TransactionLevel.LEVEL1
                                              ? ethereumToken
                                              : widget.arguments.account != null
                                                  ? widget.arguments.account.token
                                                  : widget.arguments.token,
                                          addressController.value.text,
                                          gasLimit.toInt(),
                                          getGasPrice(selectedFeeSpeed).toInt(),
                                          depositGasLimit);
                                    }
                                  : null,
                              padding: EdgeInsets.only(
                                  top: 18.0,
                                  bottom: 18.0,
                                  right: 24.0,
                                  left: 24.0),
                              disabledColor: HermezColors.blueyGreyTwo,
                              color: HermezColors.darkOrange,
                              textColor: Colors.white,
                              disabledTextColor: Colors.grey,
                              child: Text(
                                  widget.arguments.transactionType !=
                                          TransactionType.RECEIVE
                                      ? "Continue"
                                      : "Request",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'ModernEra',
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ),
                        ),
                      ),
                      widget.arguments.account != null
                          ? Container(
                              alignment: Alignment.center,
                              margin: EdgeInsets.only(top: 24.0),
                              child: TextButton(
                                onPressed: ((widget.arguments.txLevel ==
                                                TransactionLevel.LEVEL2 &&
                                            widget.arguments.transactionType ==
                                                TransactionType.SEND) ||
                                        snapshot.connectionState !=
                                            ConnectionState.done
                                    ? null
                                    : () {
                                        if (widget.arguments.transactionType ==
                                                TransactionType.EXIT ||
                                            widget.arguments.transactionType ==
                                                TransactionType.FORCEEXIT) {
                                          setState(() {
                                            showEstimatedFees =
                                                !showEstimatedFees;
                                          });
                                        } else {
                                          Navigator.of(context).pushNamed(
                                              "/fee_selector",
                                              arguments: FeeSelectorArguments(
                                                  widget.arguments.store,
                                                  selectedFee: selectedFeeSpeed,
                                                  ethereumToken: ethereumToken,
                                                  estimatedGas: gasLimit,
                                                  gasPriceResponse:
                                                      gasPriceResponse,
                                                  onFeeSelected: (selectedFee) {
                                                setState(() {
                                                  amountController.clear();
                                                  selectedFeeSpeed =
                                                      selectedFee;
                                                });
                                              }));
                                        }
                                      }),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      feeText,
                                      style: TextStyle(
                                        color: ((widget.arguments.txLevel ==
                                                        TransactionLevel
                                                            .LEVEL2 &&
                                                    widget.arguments
                                                            .transactionType ==
                                                        TransactionType
                                                            .SEND)) ||
                                                snapshot.connectionState !=
                                                    ConnectionState.done
                                            ? HermezColors.blueyGreyTwo
                                            : HermezColors.blackTwo,
                                        fontSize: 16,
                                        fontFamily: 'ModernEra',
                                        fontWeight: (widget.arguments.txLevel ==
                                                        TransactionLevel
                                                            .LEVEL2 &&
                                                    widget.arguments
                                                            .transactionType ==
                                                        TransactionType.SEND) ||
                                                snapshot.connectionState !=
                                                    ConnectionState.done
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    (widget.arguments.txLevel ==
                                                TransactionLevel.LEVEL2 &&
                                            widget.arguments.transactionType ==
                                                TransactionType.SEND)
                                        ? Container()
                                        : snapshot.connectionState ==
                                                ConnectionState.done
                                            ? widget.arguments.transactionType ==
                                                        TransactionType.EXIT ||
                                                    widget.arguments.transactionType ==
                                                        TransactionType
                                                            .FORCEEXIT
                                                ? Container(
                                                    alignment: Alignment.center,
                                                    margin: EdgeInsets.only(
                                                        left: 6, bottom: 2),
                                                    child: SvgPicture.asset(
                                                        showEstimatedFees
                                                            ? 'assets/arrow_up.svg'
                                                            : 'assets/arrow_down.svg',
                                                        color: HermezColors
                                                            .blackTwo,
                                                        semanticsLabel:
                                                            'fee_selector'))
                                                : Container(
                                                    alignment: Alignment.center,
                                                    margin: EdgeInsets.only(
                                                        left: 6, bottom: 2),
                                                    child: SvgPicture.asset(
                                                        'assets/arrow_right.svg',
                                                        color: HermezColors
                                                            .blackTwo,
                                                        semanticsLabel:
                                                            'fee_selector'),
                                                  )
                                            : Container(
                                                alignment: Alignment.center,
                                                margin: EdgeInsets.only(left: 6, bottom: 1),
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      new AlwaysStoppedAnimation<
                                                              Color>(
                                                          HermezColors
                                                              .blueyGrey),
                                                  strokeWidth: 2,
                                                ),
                                                width: 10,
                                                height: 10),
                                  ],
                                ),
                              ),
                            )
                          : Container(),
                      showEstimatedFees && needRefresh == false
                          ? buildFeesList()
                          : Container(),
                    ],
                  ),
                ],
                children: <Widget>[
                  widget.arguments.transactionType == TransactionType.EXIT ||
                          widget.arguments.transactionType ==
                              TransactionType.DEPOSIT
                      ? MoveRow(
                          widget.arguments.txLevel,
                          widget.arguments.allowChangeLevel &&
                                  needRefresh == false
                              ? () async {
                                  setState(() {
                                    gasPriceResponse = null;
                                    if ((widget.arguments.txLevel ==
                                        TransactionLevel.LEVEL1)) {
                                      widget.arguments.txLevel =
                                          TransactionLevel.LEVEL2;
                                      widget.arguments.transactionType =
                                          TransactionType.EXIT;
                                    } else {
                                      widget.arguments.txLevel =
                                          TransactionLevel.LEVEL1;
                                      widget.arguments.transactionType =
                                          TransactionType.DEPOSIT;
                                    }
                                    defaultCurrencySelected = true;
                                    widget.arguments.account = null;
                                    amountController.clear();
                                  });
                                }
                              : null,
                        )
                      : Container(),
                  widget.arguments.account != null ||
                          widget.arguments.token != null
                      ? AccountRow(
                          widget.arguments.account != null
                              ? widget.arguments.account.token.name
                              : widget.arguments.token.name,
                          widget.arguments.account != null
                              ? widget.arguments.account.token.symbol
                              : widget.arguments.token.symbol,
                          currency != "USD"
                              ? (widget.arguments.account != null
                                      ? widget.arguments.account.token.USD
                                      : widget.arguments.token.USD) *
                                  widget.arguments.store.state.exchangeRatio
                              : widget.arguments.account != null
                                  ? widget.arguments.account.token.USD
                                  : widget.arguments.token.USD,
                          currency,
                          widget.arguments.account != null
                              ? double.parse(widget.arguments.account.balance) /
                                  pow(10,
                                      widget.arguments.account.token.decimals)
                              : 0,
                          true,
                          defaultCurrencySelected,
                          false,
                          widget.arguments.token != null,
                          (_, amount) async {
                            Navigator.of(context).pushNamed("/account_selector",
                                arguments: AccountSelectorArguments(
                                    widget.arguments.txLevel,
                                    widget.arguments.transactionType,
                                    widget.arguments.store,
                                    onAccountSelected: (selectedAccount) {
                                  setState(() {
                                    amountController.clear();
                                    needRefresh = true;
                                    widget.arguments.account = selectedAccount;
                                  });
                                }, onTokenSelected: (selectedToken) {
                                  setState(() {
                                    amountController.clear();
                                    needRefresh = true;
                                    widget.arguments.token = selectedToken;
                                  });
                                }));
                          },
                        )
                      : Container(
                          padding: EdgeInsets.only(bottom: 15.0),
                          child: FlatButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side:
                                    BorderSide(color: HermezColors.lightGrey)),
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                  "/account_selector",
                                  arguments: AccountSelectorArguments(
                                      widget.arguments.txLevel,
                                      widget.arguments.transactionType,
                                      widget.arguments.store,
                                      onAccountSelected: (selectedAccount) {
                                    setState(() {
                                      amountController.clear();
                                      needRefresh = true;
                                      widget.arguments.account =
                                          selectedAccount;
                                    });
                                  }, onTokenSelected: (selectedToken) {
                                    setState(() {
                                      amountController.clear();
                                      needRefresh = true;
                                      widget.arguments.token = selectedToken;
                                    });
                                  }));
                            },
                            padding: EdgeInsets.all(20.0),
                            color: HermezColors.lightGrey,
                            textColor: HermezColors.blackTwo,
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Container(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Select token',
                                          style: TextStyle(
                                            color: HermezColors.blackTwo,
                                            fontSize: 16,
                                            fontFamily: 'ModernEra',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ), //title to be name of the crypto
                          )),
                  enoughGas == false && !needRefresh
                      ? _buildNoGasRow()
                      : Container(),
                  _buildAmountRow(
                      context, null, amountController, estimatedFee),
                  widget.arguments.transactionType == TransactionType.SEND
                      ? _buildAddressRow()
                      : Container()
                ],
              ),
            ),
          );
        } else {
          // We can show the loading view until the data comes back.
          //debugPrint('Step 1, build loading widget');
          return new Center(
            child: new CircularProgressIndicator(),
          );
        }
      },
    );
  }

  Widget _buildNoGasRow() {
    final String currency =
        widget.arguments.store.state.defaultCurrency.toString().split('.').last;
    double currencyExchange = (ethereumToken.USD *
        (currency != "USD" ? widget.arguments.store.state.exchangeRatio : 1));
    double exitFee = 0;
    if (widget.arguments.transactionType == TransactionType.FORCEEXIT) {
      // fee force exit l1
      BigInt gasPrice = getGasPrice(selectedFeeSpeed);
      BigInt estimatedFee = gasLimit * gasPrice;
      exitFee = estimatedFee.toDouble() / pow(10, ethereumToken.decimals);
    }
    BigInt withdrawGasPrice = getGasPrice(selectedWithdrawFeeSpeed);
    BigInt withdrawEstimatedFee = withdrawGasLimit * withdrawGasPrice;
    double withdrawFee =
        withdrawEstimatedFee.toDouble() / pow(10, ethereumToken.decimals);

    String currencyFee = EthAmountFormatter.formatAmount(
        (exitFee + withdrawFee) * currencyExchange, currency);
    String tokenFee = EthAmountFormatter.formatAmount(
        exitFee + withdrawFee, ethereumToken.symbol);
    return Card(
      margin: EdgeInsets.only(bottom: 15),
      color: HermezColors.blackTwo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.only(top: 16, bottom: 16, right: 24, left: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8, right: 12),
              child: SvgPicture.asset("assets/info.svg",
                  color: HermezColors.lightGrey,
                  alignment: Alignment.topLeft,
                  height: 20),
            ),
            Flexible(
              flex: 1,
              child: Text(
                'You don’t have enough ETH in your Ethereum wallet'
                        ' to cover moving transaction fee (you need at least ' +
                    currencyFee +
                    ' ~ ' +
                    tokenFee +
                    ').',
                style: TextStyle(
                  color: HermezColors.lightGrey,
                  fontFamily: 'ModernEra',
                  fontSize: 15,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(BuildContext context, dynamic element,
      dynamic amountController, BigInt estimatedFee) {
    final String currency =
        widget.arguments.store.state.defaultCurrency.toString().split('.').last;
    // returns a row with the desired properties
    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: (amountIsValid && enoughGas) || needRefresh
                  ? HermezColors.blueyGreyThree
                  : HermezColors.redError,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.only(top: 20.0),
          child: Container(
            child: Column(
              children: <Widget>[
                Container(
                  child: Text(
                    defaultCurrencySelected ||
                            widget.arguments.account == null &&
                                widget.arguments.token == null
                        ? currency
                        : widget.arguments.account != null
                            ? widget.arguments.account.token.symbol
                            : widget.arguments.token.symbol,
                    style: TextStyle(
                      color: HermezColors.black,
                      fontSize: 16,
                      fontFamily: 'ModernEra',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 10.0),
                  child: AmountInput(
                    onChanged: (value) {
                      setState(() {
                        if (value.isNotEmpty) {
                          double amount = double.parse(value);
                          amountIsValid = isAmountValid(amount.toString());
                        } else {
                          amountIsValid = isAmountValid('0');
                        }
                      });
                    },
                    enabled: widget.arguments.account != null ||
                        widget.arguments.transactionType ==
                            TransactionType.RECEIVE,
                    controller: amountController,
                    decimals: defaultCurrencySelected ? 2 : 6,
                  ),
                ),
                SizedBox(
                  height: widget.arguments.account != null ||
                          widget.arguments.token != null
                      ? 16.0
                      : 25,
                ),
                widget.arguments.account != null ||
                        widget.arguments.token != null
                    ? Divider(
                        color: HermezColors.blueyGreyThree,
                        height: 2,
                        thickness: 2,
                      )
                    : Container(),
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      widget.arguments.account != null ||
                              widget.arguments.token != null &&
                                  widget.arguments.transactionType !=
                                      TransactionType.RECEIVE
                          ? Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border(
                                      top: BorderSide.none,
                                      right: BorderSide(
                                          color: HermezColors.blueyGreyThree,
                                          width: 1),
                                      bottom: BorderSide.none,
                                      left: BorderSide.none),
                                ),
                                child: FlatButton(
                                  child: Text(
                                    "Send All",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: HermezColors.blueyGreyTwo,
                                      fontSize: 16,
                                      fontFamily: 'ModernEra',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (!needRefresh) {
                                      setState(() {
                                        amountController.clear();
                                        double amount = getMaxAmount();
                                        amountIsValid =
                                            isAmountValid(amount.toString());
                                        if (amountIsValid) {
                                          amountController.text =
                                              amount.toStringAsFixed(
                                                  defaultCurrencySelected
                                                      ? amount.truncateToDouble() ==
                                                              amount
                                                          ? 0
                                                          : 2
                                                      : amount.truncateToDouble() ==
                                                              amount
                                                          ? 0
                                                          : 6);
                                          amountController.selection =
                                              TextSelection.fromPosition(
                                                  TextPosition(
                                                      offset: amountController
                                                          .text.length));
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            )
                          : Container(),
                      widget.arguments.account != null ||
                              widget.arguments.token != null
                          ? Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border(
                                      top: BorderSide.none,
                                      right: BorderSide.none,
                                      bottom: BorderSide.none,
                                      left: BorderSide(
                                          color: HermezColors.blueyGreyThree,
                                          width: 1)),
                                ),
                                child: FlatButton.icon(
                                  onPressed: () {
                                    if (widget.arguments.account != null ||
                                        widget.arguments.token != null) {
                                      setState(() {
                                        amountController.clear();
                                        defaultCurrencySelected =
                                            !defaultCurrencySelected;
                                      });
                                    }
                                  },
                                  icon: Image.asset(
                                    "assets/arrows_up_down.png",
                                    color: HermezColors.blueyGreyTwo,
                                  ),
                                  label: Text(
                                    defaultCurrencySelected
                                        ? widget.arguments.account != null
                                            ? widget
                                                .arguments.account.token.symbol
                                            : widget.arguments.token.symbol
                                        : currency,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: HermezColors.blueyGreyTwo,
                                      fontSize: 16,
                                      fontFamily: 'ModernEra',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(),
                    ],
                  ),
                ),
              ],
            ), //title to be name of the crypto
          ),
        ),
        amountIsValid || !enoughGas || needRefresh
            ? SizedBox(
                height: 40,
              )
            : Container(
                padding: EdgeInsets.only(top: 10, bottom: 15),
                child: Row(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(left: 8.0, right: 8.0),
                      height: 16,
                      width: 16,
                      decoration: BoxDecoration(
                        color: HermezColors.redError,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          '!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'ModernEra',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'You don’t have enough funds.',
                      style: TextStyle(
                        color: HermezColors.redError,
                        fontFamily: 'ModernEra',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildAddressRow() {
    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: addressIsValid || needRefresh
                  ? HermezColors.blueyGreyThree
                  : HermezColors.redError,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 10.0),
          child: Container(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AddressInput(
                    controller: addressController,
                    layerOne:
                        widget.arguments.txLevel == TransactionLevel.LEVEL1,
                    onChanged: (value) {
                      setState(() {
                        addressIsValid = isAddressValid();
                        if (addressIsValid) {
                          amountController.clear();
                          needRefresh = true;
                        }
                      });
                    },
                  ),
                ),
                addressController.value.text.isEmpty
                    ? Row(
                        children: <Widget>[
                          Container(
                            child: FlatButton(
                              child: Text(
                                'Paste',
                                style: TextStyle(
                                  color: HermezColors.blackTwo,
                                  fontFamily: 'ModernEra',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () {
                                getClipBoardData().then((String result) {
                                  setState(() {
                                    addressController.clear();
                                    addressController.text = result;
                                    addressIsValid = isAddressValid();
                                    if (addressIsValid) {
                                      amountController.clear();
                                      needRefresh = true;
                                    }
                                  });
                                });
                              },
                            ),
                          ),
                          Container(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushNamed("/scanner",
                                    arguments: QRCodeScannerArguments(
                                        store: widget.arguments.store,
                                        type: widget.arguments.txLevel ==
                                                TransactionLevel.LEVEL1
                                            ? QRCodeScannerType.ETHEREUM_ADDRESS
                                            : QRCodeScannerType.HERMEZ_ADDRESS,
                                        onScanned: (scannedAddress) async {
                                          setState(() {
                                            addressController.clear();
                                            addressController.text =
                                                scannedAddress.toString();
                                            addressIsValid = isAddressValid();
                                            if (addressIsValid) {
                                              amountController.clear();
                                              needRefresh = true;
                                            }
                                          });
                                        }));
                              }, // handle your image tap here
                              child: SvgPicture.asset(
                                "assets/scan.svg",
                                color: HermezColors.blackTwo,
                              ),
                            ),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: new Icon(Icons.close),
                        onPressed: () => setState(() {
                          addressController.clear();
                          addressIsValid = isAddressValid();
                          if (addressIsValid) {
                            amountController.clear();
                            needRefresh = true;
                          }
                        }),
                      ),
              ],
            ),
          ),
        ),
        addressIsValid || needRefresh
            ? SizedBox(
                height: 40,
              )
            : Container(
                padding: EdgeInsets.only(top: 10, bottom: 15),
                child: Row(
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(left: 8.0, right: 8.0),
                      height: 16,
                      width: 16,
                      decoration: BoxDecoration(
                        color: HermezColors.redError,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          '!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'ModernEra',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Please enter a valid address.',
                      style: TextStyle(
                        color: HermezColors.redError,
                        fontFamily: 'ModernEra',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  //widget that builds the list
  Widget buildFeesList() {
    final String currency =
        widget.arguments.store.state.defaultCurrency.toString().split('.').last;

    return ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: 2,
        separatorBuilder: (BuildContext context, int index) {
          return Container(
              padding: const EdgeInsets.only(left: 10.0, right: 10.0),
              child: Divider(color: HermezColors.steel));
        },
        itemBuilder: (context, i) {
          String title = "";
          String currencyFee = "";
          String tokenFee = "";
          String speed = "";
          if (i == 0) {
            Token token;
            if (widget.arguments.transactionType == TransactionType.EXIT) {
              title = "Hermez fee";
              token = widget.arguments.account.token;
            } else if (widget.arguments.transactionType ==
                TransactionType.FORCEEXIT) {
              title = "Ethereum fee";
              token = ethereumToken;
            }
            BigInt estimatedFee = getEstimatedFee();
            currencyFee = EthAmountFormatter.formatAmount(
                estimatedFee.toDouble() /
                    pow(10, token.decimals) *
                    (token.USD *
                        (currency != "USD"
                            ? widget.arguments.store.state.exchangeRatio
                            : 1)),
                currency);

            tokenFee = EthAmountFormatter.formatAmount(
                estimatedFee.toDouble() / pow(10, token.decimals),
                token.symbol);

            speed =
                selectedFeeSpeed.toString().split(".").last.substring(0, 1) +
                    selectedFeeSpeed
                        .toString()
                        .split(".")
                        .last
                        .substring(1)
                        .toLowerCase();
          } else {
            title = "Ethereum fee\n(estimated)";
            BigInt gasPrice = getGasPrice(selectedWithdrawFeeSpeed);

            BigInt estimatedFee = withdrawGasLimit * gasPrice;
            currencyFee = EthAmountFormatter.formatAmount(
                estimatedFee.toDouble() /
                    pow(10, ethereumToken.decimals) *
                    (ethereumToken.USD *
                        (currency != "USD"
                            ? widget.arguments.store.state.exchangeRatio
                            : 1)),
                currency);

            tokenFee = EthAmountFormatter.formatAmount(
                estimatedFee.toDouble() / pow(10, ethereumToken.decimals),
                ethereumToken.symbol);

            speed = selectedWithdrawFeeSpeed
                    .toString()
                    .split(".")
                    .last
                    .substring(0, 1) +
                selectedWithdrawFeeSpeed
                    .toString()
                    .split(".")
                    .last
                    .substring(1)
                    .toLowerCase();
          }
          String subtitle = "Step " + (i + 1).toString();

          return ListTile(
              title: Container(
                padding: EdgeInsets.only(top: 16.0, bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            child: Text(
                              title,
                              style: TextStyle(
                                  fontFamily: 'ModernEra',
                                  color: HermezColors.blackTwo,
                                  fontWeight: FontWeight.w500,
                                  height: 1.71,
                                  fontSize: 16),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Container(
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                  fontFamily: 'ModernEra',
                                  color: HermezColors.blueyGreyTwo,
                                  fontWeight: FontWeight.w500,
                                  height: 1.53,
                                  fontSize: 16),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          child: Text(
                            currencyFee,
                            style: TextStyle(
                                fontFamily: 'ModernEra',
                                color: HermezColors.blackTwo,
                                fontWeight: FontWeight.w700,
                                height: 1.71,
                                fontSize: 16),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        Container(
                          child: Text(
                            tokenFee,
                            style: TextStyle(
                                fontFamily: 'ModernEra',
                                color: HermezColors.blueyGreyTwo,
                                fontWeight: FontWeight.w500,
                                height: 1.53,
                                fontSize: 15),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        widget.arguments.transactionType ==
                                    TransactionType.FORCEEXIT ||
                                i == 1
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    child: Text(
                                      speed,
                                      style: TextStyle(
                                          fontFamily: 'ModernEra',
                                          color: HermezColors.blackTwo,
                                          fontWeight: FontWeight.w700,
                                          height: 1.73,
                                          fontSize: 15),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    margin: EdgeInsets.only(left: 6, top: 4),
                                    child: SvgPicture.asset(
                                        'assets/arrow_right.svg',
                                        color: HermezColors.blackTwo,
                                        semanticsLabel: 'fee_selector'),
                                  )
                                ],
                              )
                            : Container(),
                      ],
                    ),
                  ],
                ),
              ),
              onTap: widget.arguments.transactionType ==
                          TransactionType.FORCEEXIT ||
                      i == 1
                  ? () {
                      Navigator.of(context).pushNamed("/fee_selector",
                          arguments: FeeSelectorArguments(
                              widget.arguments.store,
                              selectedFee: i == 0
                                  ? selectedFeeSpeed
                                  : selectedWithdrawFeeSpeed,
                              ethereumToken: ethereumToken,
                              estimatedGas:
                                  i == 0 ? gasLimit : withdrawGasLimit,
                              gasPriceResponse: gasPriceResponse,
                              onFeeSelected: (selectedFee) {
                            setState(() {
                              amountController.clear();
                              if (i == 0) {
                                selectedFeeSpeed = selectedFee;
                              } else {
                                selectedWithdrawFeeSpeed = selectedFee;
                              }
                            });
                          }));
                    }
                  : null);
        });
  }

  void onSubmit(
      double amount,
      Token token,
      double fee,
      Token feeToken,
      String address,
      int gasLimit,
      int gasPrice,
      LinkedHashMap<String, BigInt> depositGasLimit) {
    if (widget.arguments.transactionType == TransactionType.RECEIVE) {
      Navigator.of(context).pushReplacementNamed("/qrcode",
          arguments: QRCodeArguments(
              qrCodeType: QRCodeType.REQUEST_PAYMENT,
              code: widget.arguments.txLevel == TransactionLevel.LEVEL1
                  ? widget.arguments.store.state.ethereumAddress
                  : getHermezAddress(
                      widget.arguments.store.state.ethereumAddress),
              store: widget.arguments.store,
              amount: amount,
              token: token,
              isReceive: true));
    } else {
      String addressTo;
      if (widget.arguments.transactionType == TransactionType.DEPOSIT) {
        addressTo = getCurrentEnvironment().contracts['Hermez'];
      } else if ((widget.arguments.transactionType == TransactionType.EXIT ||
              widget.arguments.transactionType == TransactionType.FORCEEXIT) &&
          address.isEmpty) {
        addressTo =
            getEthereumAddress(widget.arguments.account.hezEthereumAddress);
      } else {
        addressTo = address;
      }
      //var success = await transferStore.transfer(address, amount);
      Navigator.pushNamed(context, "/transaction_details",
              arguments: TransactionDetailsArguments(
                  wallet: widget.arguments.store,
                  transactionType: widget.arguments.transactionType,
                  status: TransactionStatus.DRAFT,
                  account: widget.arguments.account,
                  token: widget.arguments.account.token,
                  amount: amount,
                  addressFrom: widget.arguments.account.hezEthereumAddress,
                  addressTo: addressTo,
                  fee: fee,
                  feeToken: feeToken,
                  feeAccount: ethereumAccount,
                  gasLimit: gasLimit,
                  gasPrice: gasPrice,
                  depositGasLimit: depositGasLimit))
          .then((value) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }
  }

  Future<String> getClipBoardData() async {
    ClipboardData data = await Clipboard.getData(Clipboard.kTextPlain);
    return data.text;
  }

  Future<void> calculateFees() async {
    BigInt gasPrice = BigInt.zero;
    if (widget.arguments.transactionType == TransactionType.RECEIVE) {
      gasLimit = BigInt.zero;
    } else if (widget.arguments.transactionType == TransactionType.FORCEEXIT) {
      // calculate fee l1 (force exit) and l1 (withdraw)

      // fee l1 (force exit)
      gasPriceResponse = await widget.arguments.store.getGasPrice();
      ethereumToken = await getEthereumToken();
      ethereumAccount = await getEthereumAccount();
      if (widget.arguments.account != null) {
        BigInt amountToEstimate = BigInt.one;
        gasLimit = await widget.arguments.store
            .forceExitGasLimit(amountToEstimate, widget.arguments.account);
      }
      gasPrice = getGasPrice(selectedFeeSpeed);

      // fee l1 (withdraw)
      withdrawGasLimit = BigInt.from(GAS_LIMIT_WITHDRAW_DEFAULT);
      withdrawGasLimit += BigInt.from(GAS_LIMIT_WITHDRAW_SIBLING * 4);
      if (widget.arguments.account.token.id != 0) {
        withdrawGasLimit += BigInt.from(GAS_STANDARD_ERC20_TX);
      }

      gasPrice = getGasPrice(selectedFeeSpeed);
      BigInt withdrawGasPrice = getGasPrice(selectedWithdrawFeeSpeed);
      enoughGas = await isEnoughGas(
          (gasLimit * gasPrice) + (withdrawGasLimit * withdrawGasPrice));

      double amount = 0;
      if (widget.arguments.account != null) {
        if (amountController.value.text.isNotEmpty) {
          amount = !defaultCurrencySelected
              ? double.parse(amountController.value.text)
              : double.parse(amountController.value.text) /
                  widget.arguments.account.token.USD;
        }
      }
      amountIsValid =
          isAmountValid(EthAmountFormatter.removeDecimalZeroFormat(amount));
    } else if (widget.arguments.transactionType == TransactionType.EXIT) {
      // calculate fee l2 and l1

      // fee withdraw l1 --> 230k + Transfer cost + (31k * siblings.length)
      gasPriceResponse = await widget.arguments.store.getGasPrice();
      ethereumToken = await getEthereumToken();
      ethereumAccount = await getEthereumAccount();
      withdrawGasLimit = BigInt.from(GAS_LIMIT_WITHDRAW_DEFAULT);
      withdrawGasLimit += BigInt.from(GAS_LIMIT_WITHDRAW_SIBLING * 4);
      if (widget.arguments.account.token.id != 0) {
        withdrawGasLimit += BigInt.from(GAS_STANDARD_ERC20_TX);
      }

      // fee l2
      gasLimit = BigInt.zero;
      if (widget.arguments.account != null) {
        StateResponse state = await widget.arguments.store.getState();
        RecommendedFee fees = state.recommendedFee;
        gasLimit = BigInt.from(fees.existingAccount /
            widget.arguments.account.token.USD *
            pow(10, widget.arguments.account.token.decimals));
      }
      gasPrice = getGasPrice(selectedWithdrawFeeSpeed);
      enoughGas = await isEnoughGas(withdrawGasLimit * gasPrice);

      double amount = 0;
      if (widget.arguments.account != null) {
        if (amountController.value.text.isNotEmpty) {
          amount = !defaultCurrencySelected
              ? double.parse(amountController.value.text)
              : double.parse(amountController.value.text) /
                  widget.arguments.account.token.USD;
        }
      }
      amountIsValid =
          isAmountValid(EthAmountFormatter.removeDecimalZeroFormat(amount));
    } else if (widget.arguments.transactionType == TransactionType.SEND) {
      if (widget.arguments.txLevel == TransactionLevel.LEVEL1) {
        // calculate fee L1
        gasPriceResponse = await widget.arguments.store.getGasPrice();
        ethereumToken = await getEthereumToken();
        ethereumAccount = await getEthereumAccount();
        gasLimit = BigInt.from(GAS_LIMIT_HIGH);
        if (widget.arguments.account.token.id != 0) {
          gasLimit += BigInt.from(GAS_STANDARD_ERC20_TX);
        }
        gasPrice = getGasPrice(selectedFeeSpeed);
        enoughGas = await isEnoughGas(gasLimit * gasPrice);

        double amount = 0;
        if (widget.arguments.account != null) {
          if (amountController.value.text.isNotEmpty) {
            amount = !defaultCurrencySelected
                ? double.parse(amountController.value.text)
                : double.parse(amountController.value.text) /
                    widget.arguments.account.token.USD;
          }
        }
        amountIsValid =
            isAmountValid(EthAmountFormatter.removeDecimalZeroFormat(amount));
      } else {
        // calculate fee L2
        gasLimit = BigInt.zero;
        if (widget.arguments.account != null) {
          StateResponse state = await widget.arguments.store.getState();
          RecommendedFee fees = state.recommendedFee;
          gasLimit = BigInt.from(fees.existingAccount /
              widget.arguments.account.token.USD *
              pow(10, widget.arguments.account.token.decimals));
        }
        enoughGas = await isEnoughGas(gasLimit);

        double amount = 0;
        if (widget.arguments.account != null) {
          if (amountController.value.text.isNotEmpty) {
            amount = !defaultCurrencySelected
                ? double.parse(amountController.value.text)
                : double.parse(amountController.value.text) /
                    widget.arguments.account.token.USD;
          }
        }
        amountIsValid =
            isAmountValid(EthAmountFormatter.removeDecimalZeroFormat(amount));
      }
    } else if (widget.arguments.transactionType == TransactionType.DEPOSIT ||
        widget.arguments.transactionType == TransactionType.WITHDRAW) {
      // calculate fee L1
      gasPriceResponse = await widget.arguments.store.getGasPrice();
      ethereumToken = await getEthereumToken();
      ethereumAccount = await getEthereumAccount();

      if (widget.arguments.transactionType == TransactionType.DEPOSIT) {
        String addressTo = getCurrentEnvironment().contracts['Hermez'];
        gasLimit = BigInt.zero;
        if (widget.arguments.account != null) {
          BigInt amountToEstimate = BigInt.one;
          depositGasLimit = await widget.arguments.store.depositGasLimit(
              amountToEstimate, widget.arguments.account.token);
          depositGasLimit.forEach((String key, BigInt value) {
            gasLimit += value;
          });
        }
        gasPrice = getGasPrice(selectedFeeSpeed);
        enoughGas = await isEnoughGas(gasLimit * gasPrice);
      } else if (widget.arguments.transactionType == TransactionType.WITHDRAW) {
        gasLimit = BigInt.from(GAS_LIMIT_WITHDRAW_DEFAULT);
        gasLimit += BigInt.from(GAS_LIMIT_WITHDRAW_SIBLING * 4);
        if (widget.arguments.account.token.id != 0) {
          gasLimit += BigInt.from(GAS_STANDARD_ERC20_TX);
        }
        gasPrice = getGasPrice(selectedFeeSpeed);
        enoughGas = await isEnoughGas(gasLimit * gasPrice);
      }

      double amount = 0;
      if (widget.arguments.account != null) {
        if (amountController.value.text.isNotEmpty) {
          amount = !defaultCurrencySelected
              ? double.parse(amountController.value.text)
              : double.parse(amountController.value.text) /
                  widget.arguments.account.token.USD;
        }
      }
      amountIsValid =
          isAmountValid(EthAmountFormatter.removeDecimalZeroFormat(amount));
    }
  }

  Future<bool> fetchData() async {
    if (needRefresh == true) {
      await calculateFees();
      needRefresh = false;
    }
    return true;
  }

  bool isButtonEnabled() {
    if (widget.arguments.transactionType == TransactionType.RECEIVE) {
      return amountIsValid &&
          amountController.value.text.isNotEmpty &&
          double.parse(amountController.value.text) > 0 &&
          widget.arguments.token != null &&
          needRefresh == false;
    } else if (widget.arguments.txLevel == TransactionLevel.LEVEL1) {
      if (widget.arguments.transactionType == TransactionType.SEND) {
        return amountIsValid &&
            enoughGas &&
            amountController.value.text.isNotEmpty &&
            double.parse(amountController.value.text) > 0 &&
            addressIsValid &&
            addressController.value.text.isNotEmpty &&
            needRefresh == false;
      } else {
        return amountIsValid &&
            enoughGas &&
            amountController.value.text.isNotEmpty &&
            double.parse(amountController.value.text) > 0 &&
            needRefresh == false;
      }
    } else {
      if (widget.arguments.transactionType == TransactionType.SEND) {
        return amountIsValid &&
            enoughGas &&
            amountController.value.text.isNotEmpty &&
            double.parse(amountController.value.text) > 0 &&
            addressIsValid &&
            addressController.value.text.isNotEmpty &&
            needRefresh == false;
      } else {
        return amountIsValid &&
            enoughGas &&
            amountController.value.text.isNotEmpty &&
            double.parse(amountController.value.text) > 0 &&
            needRefresh == false;
      }
    }
  }

  bool isAddressValid() {
    return addressController.value.text.isEmpty ||
        (widget.arguments.txLevel == TransactionLevel.LEVEL1 &&
            AddressUtils.isValidEthereumAddress(
                addressController.value.text)) ||
        (widget.arguments.txLevel == TransactionLevel.LEVEL2 &&
            isHermezEthereumAddress(addressController.value.text));
  }

  bool isAmountValid(String value) {
    double amount = 0;
    BigInt estimatedFee = BigInt.zero;
    double balance = 1;

    if (widget.arguments.account != null) {
      if (widget.arguments.transactionType == TransactionType.DEPOSIT &&
              widget.arguments.account.token.id == 0 ||
          (widget.arguments.transactionType != TransactionType.DEPOSIT &&
              widget.arguments.txLevel == TransactionLevel.LEVEL1 &&
              widget.arguments.account.token.id == 0) ||
          widget.arguments.transactionType == TransactionType.EXIT ||
          (widget.arguments.transactionType == TransactionType.SEND &&
              widget.arguments.txLevel == TransactionLevel.LEVEL2)) {
        estimatedFee = getEstimatedFee();
      }
      //}
      final String currency = widget.arguments.store.state.defaultCurrency
          .toString()
          .split('.')
          .last;
      double currencyValue = 0;
      if (widget.arguments.account != null) {
        currencyValue = defaultCurrencySelected
            ? widget.arguments.account.token.USD *
                (currency != 'USD'
                    ? widget.arguments.store.state.exchangeRatio
                    : 1)
            : 1;

        balance = double.parse((double.parse(widget.arguments.account.balance) /
                pow(10, widget.arguments.account.token.decimals) *
                currencyValue)
            .toStringAsFixed(defaultCurrencySelected ? 2 : 6));

        amount = double.parse((double.parse(value) +
                (currencyValue *
                    estimatedFee.toDouble() /
                    pow(10, widget.arguments.account.token.decimals)))
            .toStringAsFixed(defaultCurrencySelected ? 2 : 6));
      }
    }
    return value.isEmpty ||
        (widget.arguments.account != null ? amount <= balance : true);
  }

  double getMaxAmount() {
    double amount = 0;
    BigInt estimatedFee = BigInt.zero;
    if (widget.arguments.transactionType == TransactionType.DEPOSIT &&
            widget.arguments.account.token.id == 0 ||
        (widget.arguments.transactionType != TransactionType.DEPOSIT &&
            widget.arguments.txLevel == TransactionLevel.LEVEL1 &&
            widget.arguments.account.token.id == 0) ||
        widget.arguments.transactionType == TransactionType.EXIT ||
        (widget.arguments.transactionType == TransactionType.SEND &&
            widget.arguments.txLevel == TransactionLevel.LEVEL2)) {
      estimatedFee = getEstimatedFee();
    }

    final String currency =
        widget.arguments.store.state.defaultCurrency.toString().split('.').last;
    if (widget.arguments.account != null) {
      double currencyValue = defaultCurrencySelected
          ? widget.arguments.account.token.USD *
              (currency != 'USD'
                  ? widget.arguments.store.state.exchangeRatio
                  : 1)
          : 1;

      double balance = double.parse(
          (double.parse(widget.arguments.account.balance) /
                  pow(10, widget.arguments.account.token.decimals) *
                  currencyValue)
              .toStringAsFixed(defaultCurrencySelected ? 2 : 6));

      amount = double.parse((balance -
              (currencyValue *
                  estimatedFee.toDouble() /
                  pow(10, widget.arguments.account.token.decimals)))
          .toStringAsFixed(defaultCurrencySelected ? 2 : 6));
    }
    if (amount < 0) {
      amount = 0;
    }
    return amount;
  }

  Future<bool> isEnoughGas(BigInt gasFee) async {
    if ((widget.arguments.txLevel == TransactionLevel.LEVEL1 &&
            widget.arguments.transactionType != TransactionType.RECEIVE) ||
        widget.arguments.transactionType == TransactionType.EXIT ||
        widget.arguments.transactionType == TransactionType.FORCEEXIT) {
      if (ethereumAccount != null) {
        bool result = BigInt.parse(ethereumAccount.balance) >= gasFee;
        return result;
      }
      return false;
    } else {
      return true;
    }
  }

  Future<Token> getEthereumToken() async {
    return await widget.arguments.store.getTokenById(0);
  }

  Future<Account> getEthereumAccount() async {
    Account ethereumAccount = await widget.arguments.store.getL1Account(0);
    return ethereumAccount;
  }

  BigInt getEstimatedFee() {
    BigInt gasPrice = BigInt.one;
    if (widget.arguments.transactionType != TransactionType.EXIT) {
      gasPrice = getGasPrice(selectedFeeSpeed);
    }
    return gasLimit * gasPrice;
  }

  BigInt getGasPrice(WalletDefaultFee feeSpeed) {
    BigInt gasPrice = BigInt.one;
    if ((widget.arguments.txLevel == TransactionLevel.LEVEL1 ||
            widget.arguments.transactionType == TransactionType.EXIT ||
            widget.arguments.transactionType == TransactionType.FORCEEXIT) &&
        gasPriceResponse != null &&
        feeSpeed != null) {
      switch (feeSpeed) {
        case WalletDefaultFee.SLOW:
          gasPrice = BigInt.from(gasPriceResponse.safeLow * pow(10, 8));
          break;
        case WalletDefaultFee.AVERAGE:
          gasPrice = BigInt.from(gasPriceResponse.average * pow(10, 8));
          break;
        case WalletDefaultFee.FAST:
          gasPrice = BigInt.from(gasPriceResponse.fast * pow(10, 8));
          break;
      }
    }
    return gasPrice;
  }

  String getFeeText(ConnectionState connectionState) {
    if (widget.arguments.account == null ||
        widget.arguments.transactionType == TransactionType.RECEIVE) {
      return "";
    } else {
      return getFee(connectionState);
    }
  }

  String getFee(ConnectionState connectionState) {
    final String currency =
        widget.arguments.store.state.defaultCurrency.toString().split('.').last;
    BigInt estimatedFee = BigInt.zero;
    BigInt gasPrice = getGasPrice(selectedFeeSpeed);

    if (connectionState == ConnectionState.done) {
      estimatedFee = getEstimatedFee();
    }
    if (widget.arguments.transactionType == TransactionType.RECEIVE) {
      return "";
    } else if (widget.arguments.transactionType == TransactionType.FORCEEXIT) {
      // calculate fee l1 (force exit) && fee l1 (withdraw)

      // fee force exit l1
      double exitFee = estimatedFee.toDouble() /
          pow(10, ethereumToken.decimals) *
          (ethereumToken.USD *
              (currency != "USD"
                  ? widget.arguments.store.state.exchangeRatio
                  : 1));

      // fee withdraw l1 --> 230k + Transfer cost + (31k * siblings.length)
      // fee l1 (withdraw)
      BigInt withdrawGasPrice = getGasPrice(selectedWithdrawFeeSpeed);
      BigInt withdrawEstimatedFee = withdrawGasLimit * withdrawGasPrice;
      double withdrawFee = withdrawEstimatedFee.toDouble() /
          pow(10, ethereumToken.decimals) *
          (ethereumToken.USD *
              (currency != "USD"
                  ? widget.arguments.store.state.exchangeRatio
                  : 1));

      String feeSend =
          EthAmountFormatter.formatAmount(exitFee + withdrawFee, currency);

      return 'Total estimated fee ' + feeSend;
    } else if (widget.arguments.transactionType == TransactionType.EXIT) {
      // calculate fee l2 (exit) and l1 (withdraw)

      // fee l2 (exit)
      Token token = widget.arguments.account.token;
      double exitFee = estimatedFee.toDouble() /
          pow(10, token.decimals) *
          (token.USD *
              (currency != "USD"
                  ? widget.arguments.store.state.exchangeRatio
                  : 1));

      // fee l1 (withdraw)
      BigInt withdrawGasPrice = getGasPrice(selectedWithdrawFeeSpeed);
      BigInt withdrawEstimatedFee = withdrawGasLimit * withdrawGasPrice;
      double withdrawFee = withdrawEstimatedFee.toDouble() /
          pow(10, ethereumToken.decimals) *
          (ethereumToken.USD *
              (currency != "USD"
                  ? widget.arguments.store.state.exchangeRatio
                  : 1));

      String feeSend =
          EthAmountFormatter.formatAmount(exitFee + withdrawFee, currency);

      return 'Total estimated fee ' + feeSend;
    } else if (widget.arguments.transactionType == TransactionType.SEND) {
      Token token;
      if (widget.arguments.txLevel == TransactionLevel.LEVEL1) {
        token = ethereumToken;
      } else {
        token = widget.arguments.account.token;
      }
      String feeSend = EthAmountFormatter.formatAmount(
          estimatedFee.toDouble() /
              pow(10, token.decimals) *
              (defaultCurrencySelected
                  ? (token.USD *
                      (currency != "USD"
                          ? widget.arguments.store.state.exchangeRatio
                          : 1))
                  : 1),
          defaultCurrencySelected ? currency : token.symbol);
      return 'Fee ' + feeSend;
    } else if (widget.arguments.transactionType == TransactionType.DEPOSIT ||
        widget.arguments.transactionType == TransactionType.WITHDRAW) {
      // calculate fee L1
      String feeSend = EthAmountFormatter.formatAmount(
          estimatedFee.toDouble() /
              pow(10, ethereumToken.decimals) *
              (defaultCurrencySelected
                  ? (ethereumToken.USD *
                      (currency != "USD"
                          ? widget.arguments.store.state.exchangeRatio
                          : 1))
                  : 1),
          defaultCurrencySelected ? currency : ethereumToken.symbol);
      return 'Fee ' + feeSend;
    }
  }
}
