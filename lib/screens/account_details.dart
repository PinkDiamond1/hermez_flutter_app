import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hermez/components/wallet/withdrawal_row.dart';
import 'package:hermez/model/wallet.dart';
import 'package:hermez/screens/qrcode.dart';
import 'package:hermez/screens/transaction_amount.dart';
import 'package:hermez/screens/transaction_details.dart';
import 'package:hermez/service/network/model/gas_price_response.dart';
import 'package:hermez/utils/blinking_text_animation.dart';
import 'package:hermez/utils/eth_amount_formatter.dart';
import 'package:hermez/utils/hermez_colors.dart';
import 'package:hermez_plugin/addresses.dart';
import 'package:hermez_plugin/constants.dart';
import 'package:hermez_plugin/environment.dart';
import 'package:hermez_plugin/model/account.dart';
import 'package:hermez_plugin/model/exit.dart';
import 'package:hermez_plugin/model/forged_transaction.dart';
import 'package:hermez_plugin/model/l1info.dart';
import 'package:hermez_plugin/model/pool_transaction.dart';
import 'package:hermez_plugin/model/token.dart';
import 'package:hermez_plugin/utils.dart';
import 'package:intl/intl.dart';

import '../context/wallet/wallet_handler.dart';

// You can pass any object to the arguments parameter.
// In this example, create a class that contains a customizable
// title and message.

class AccountDetailsArguments {
  final WalletHandler store;
  Account account;
  BuildContext parentContext;

  AccountDetailsArguments(this.store, this.account, this.parentContext);
}

class AccountDetailsPage extends StatefulWidget {
  AccountDetailsPage({Key key, this.arguments}) : super(key: key);

  final AccountDetailsArguments arguments;

  @override
  _AccountDetailsPageState createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> {
  bool _isLoading = true;
  int fromItem = 0;
  int pendingItems = 0;
  List<dynamic> transactions = [];
  List<Exit> exits = [];
  List<Exit> filteredExits = [];
  List<dynamic> poolTxs = [];
  List<dynamic> pendingExits = [];
  List<dynamic> pendingWithdraws = [];
  List<dynamic> pendingDeposits = [];
  final ScrollController _controller = ScrollController();

  double balance = 0.0;

  Future<void> _onRefresh() {
    fromItem = 0;
    exits = [];
    filteredExits = [];
    poolTxs = [];
    pendingExits = [];
    pendingWithdraws = [];
    pendingDeposits = [];
    transactions = [];

    setState(() {
      _isLoading = true;
      fetchData();
    });
    return Future.value(null);
  }

  @override
  void initState() {
    _controller.addListener(_onScroll);
    fetchData();
    super.initState();
  }

  @override
  void setState(fn) {
    if (this.mounted) {
      super.setState(fn);
    }
  }

  _onScroll() {
    if (_controller.offset >= _controller.position.maxScrollExtent &&
        !_controller.position.outOfRange &&
        pendingItems > 0) {
      setState(() {
        _isLoading = true;
        fetchData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: NestedScrollView(
      body: Container(
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _buildTransactionsList()),
            SafeArea(
              top: false,
              bottom: true,
              child: Container(
                //height: kBottomNavigationBarHeight,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: false,
            collapsedHeight: kToolbarHeight,
            expandedHeight: 340.0,
            backgroundColor: HermezColors.lightOrange,
            elevation: 0,
            title: Container(
              padding: EdgeInsets.only(bottom: 20, top: 20),
              color: HermezColors.lightOrange,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(widget.arguments.account.token.name, // name
                          style: TextStyle(
                              fontFamily: 'ModernEra',
                              color: HermezColors.blackTwo,
                              fontWeight: FontWeight.w800,
                              fontSize: 20))
                    ],
                  )),
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                        color: HermezColors.steel),
                    padding: EdgeInsets.only(
                        left: 12.0, right: 12.0, top: 4, bottom: 4),
                    child: Text(
                      widget.arguments.store.state.txLevel ==
                              TransactionLevel.LEVEL1
                          ? "L1"
                          : "L2",
                      style: TextStyle(
                        color: HermezColors.lightOrange,
                        fontSize: 15,
                        fontFamily: 'ModernEra',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              // here the desired height*/
              background: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                      height: MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          40),
                  SizedBox(
                      width: double.infinity,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            _isLoading
                                ? BlinkingTextAnimation(
                                    arguments: BlinkingTextAnimationArguments(
                                        HermezColors.blackTwo,
                                        EthAmountFormatter.formatAmount(
                                            double.parse(widget.arguments
                                                    .account.balance) /
                                                pow(
                                                    10,
                                                    widget.arguments.account
                                                        .token.decimals),
                                            widget.arguments.account.token
                                                .symbol),
                                        32,
                                        FontWeight.w800))
                                : Text(
                                    EthAmountFormatter.formatAmount(
                                        double.parse(widget.arguments.account.balance) /
                                            pow(
                                                10,
                                                widget.arguments.account.token
                                                    .decimals),
                                        widget.arguments.account.token.symbol),
                                    style: TextStyle(
                                        color: HermezColors.blackTwo,
                                        fontFamily: 'ModernEra',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 32)),
                          ])),
                  SizedBox(height: 10),
                  _isLoading
                      ? BlinkingTextAnimation(
                          arguments: BlinkingTextAnimationArguments(
                              HermezColors.steel,
                              accountBalance(),
                              18,
                              FontWeight.w500),
                        )
                      : Text(accountBalance(),
                          style: TextStyle(
                              fontFamily: 'ModernEra',
                              fontWeight: FontWeight.w500,
                              color: HermezColors.steel,
                              fontSize: 18)),
                  SizedBox(height: 30),
                  buildButtonsRow(context),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ];
      },
    ));
  }

  buildButtonsRow(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <
        Widget>[
      SizedBox(width: 20.0),
      Expanded(
        child: FlatButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            onPressed: () {
              Navigator.pushNamed(
                widget.arguments.parentContext,
                "/transaction_amount",
                arguments: TransactionAmountArguments(widget.arguments.store,
                    widget.arguments.store.state.txLevel, TransactionType.SEND,
                    account: widget.arguments.account, allowChangeLevel: false),
              ).then((value) => _onRefresh());
            },
            padding: EdgeInsets.all(10.0),
            color: Colors.transparent,
            textColor: HermezColors.blackTwo,
            child: Column(
              children: <Widget>[
                SvgPicture.asset("assets/bt_send.svg"),
                Text(
                  'Send',
                  style: TextStyle(
                    color: HermezColors.blackTwo,
                    fontFamily: 'ModernEra',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )),
      ),
      Expanded(
        child: FlatButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            onPressed: () {
              widget.arguments.store.state.txLevel == TransactionLevel.LEVEL1
                  ? Navigator.of(widget.arguments.parentContext)
                      .pushNamed(
                        "/qrcode",
                        arguments: QRCodeArguments(
                            qrCodeType: QRCodeType.ETHEREUM,
                            code: widget.arguments.store.state.ethereumAddress,
                            store: widget.arguments.store,
                            isReceive: true),
                      )
                      .then((value) => _onRefresh())
                  : Navigator.of(widget.arguments.parentContext)
                      .pushNamed(
                        "/qrcode",
                        arguments: QRCodeArguments(
                            qrCodeType: QRCodeType.HERMEZ,
                            code: getHermezAddress(
                                widget.arguments.store.state.ethereumAddress),
                            store: widget.arguments.store,
                            isReceive: true),
                      )
                      .then((value) => _onRefresh());
            },
            padding: EdgeInsets.all(10.0),
            color: Colors.transparent,
            textColor: HermezColors.blackTwo,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 5,
                ),
                SvgPicture.asset("assets/bt_receive.svg"),
                Text(
                  'Receive',
                  style: TextStyle(
                    color: HermezColors.blackTwo,
                    fontFamily: 'ModernEra',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )),
      ),
      Expanded(
        child:
            // takes in an object and color and returns a circle avatar with first letter and required color
            FlatButton(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    widget.arguments.parentContext,
                    "/transaction_amount",
                    arguments: TransactionAmountArguments(
                        widget.arguments.store,
                        widget.arguments.store.state.txLevel,
                        widget.arguments.store.state.txLevel ==
                                TransactionLevel.LEVEL1
                            ? TransactionType.DEPOSIT
                            : TransactionType.EXIT,
                        account: widget.arguments.account,
                        allowChangeLevel: false),
                  ).then((value) => _onRefresh());
                },
                padding: EdgeInsets.all(10.0),
                color: Colors.transparent,
                textColor: HermezColors.blackTwo,
                child: Column(
                  children: <Widget>[
                    SvgPicture.asset("assets/bt_move.svg"),
                    Text(
                      'Move',
                      style: TextStyle(
                        color: HermezColors.blackTwo,
                        fontFamily: 'ModernEra',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )),
      ),
      SizedBox(width: 20.0),
    ]);
  }

  String accountBalance() {
    double resultValue = 0;
    String result = "";
    String locale = "";
    String symbol = "";
    final String currency =
        widget.arguments.store.state.defaultCurrency.toString().split('.').last;
    if (currency == "EUR") {
      locale = 'eu';
      symbol = '€';
    } else if (currency == "CNY") {
      locale = 'en';
      symbol = '\¥';
    } else {
      locale = 'en';
      symbol = '\$';
    }
    if (widget.arguments.account.token.USD != null) {
      double value = widget.arguments.account.token.USD *
          double.parse(widget.arguments.account.balance);
      if (currency != "USD") {
        value *= widget.arguments.store.state.exchangeRatio;
      }
      resultValue = resultValue + value;
    }

    //result += (resultValue / pow(10, 18)).toStringAsFixed(2);
    result = NumberFormat.currency(locale: locale, symbol: symbol)
        .format(resultValue / pow(10, 18));
    return result;
  }

  //widget that builds the list
  Widget _buildTransactionsList() {
    if (_isLoading &&
        transactions.isEmpty &&
        poolTxs.isEmpty &&
        pendingExits.isEmpty &&
        exits.isEmpty &&
        pendingWithdraws.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (!_isLoading &&
        transactions.isEmpty &&
        poolTxs.isEmpty &&
        pendingExits.isEmpty &&
        exits.isEmpty &&
        pendingWithdraws.isEmpty) {
      return Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(34.0),
          child: Text(
            'Account transactions will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HermezColors.blueyGrey,
              fontSize: 16,
              fontFamily: 'ModernEra',
              fontWeight: FontWeight.w500,
            ),
          ));
    } else {
      return Container(
        color: Colors.white,
        child: RefreshIndicator(
          child: ListView.builder(
              controller: _controller,
              shrinkWrap: true,
              // To make listView scrollable
              // even if there is only a single item.
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: (pendingExits.isNotEmpty ||
                          exits.isNotEmpty ||
                          pendingWithdraws.isNotEmpty
                      ? 1
                      : 0) +
                  transactions.length +
                  (_isLoading ? 1 : 0),
              //set the item count so that index won't be out of range
              padding: const EdgeInsets.all(16.0),
              //add some padding to make it look good
              itemBuilder: (context, i) {
                if (i == 0 && pendingExits.length > 0) {
                  final index = i;
                  final PoolTransaction transaction = pendingExits[index];

                  final Exit exit = Exit.fromTransaction(transaction);

                  final String currency = widget
                      .arguments.store.state.defaultCurrency
                      .toString()
                      .split('.')
                      .last;

                  return WithdrawalRow(exit, 1, currency,
                      widget.arguments.store.state.exchangeRatio, () async {});
                } // final index = i ~/ 2; //get the actual index excluding dividers.
                else if ((pendingExits.isNotEmpty || exits.isNotEmpty
                            /*||
                _pendingWithdraws.isNotEmpty*/
                            ? 1
                            : 0) +
                        transactions.length ==
                    i) {
                  return Center(child: CircularProgressIndicator());
                } else if (i == 0 && filteredExits.length > 0) {
                  final index = i;
                  final Exit exit = filteredExits[index];

                  final String currency = widget
                      .arguments.store.state.defaultCurrency
                      .toString()
                      .split('.')
                      .last;

                  return WithdrawalRow(exit, 2, currency,
                      widget.arguments.store.state.exchangeRatio, () async {
                    BigInt gasPrice = BigInt.one;
                    GasPriceResponse gasPriceResponse =
                        await widget.arguments.store.getGasPrice();
                    switch (widget.arguments.store.state.defaultFee) {
                      case WalletDefaultFee.SLOW:
                        int gasPriceFloor =
                            gasPriceResponse.safeLow * pow(10, 8);
                        gasPrice = BigInt.from(gasPriceFloor);
                        break;
                      case WalletDefaultFee.AVERAGE:
                        int gasPriceFloor =
                            gasPriceResponse.average * pow(10, 8);
                        gasPrice = BigInt.from(gasPriceFloor);
                        break;
                      case WalletDefaultFee.FAST:
                        int gasPriceFloor = gasPriceResponse.fast * pow(10, 8);
                        gasPrice = BigInt.from(gasPriceFloor);
                        break;
                    }

                    String addressFrom = exit.hezEthereumAddress;
                    String addressTo =
                        getCurrentEnvironment().contracts['Hermez'];

                    BigInt gasLimit = BigInt.from(GAS_LIMIT_HIGH);
                    //Token ethereumToken =
                    //await widget.arguments.store.getTokenById(0);
                    //Account ethereumAccount = await getEthereumAccount();
                    try {
                      final amountWithdraw = getTokenAmountBigInt(
                          double.parse(exit.balance) /
                              pow(10, exit.token.decimals),
                          exit.token.decimals);
                      gasLimit = await widget.arguments.store.withdrawGasLimit(
                          amountWithdraw, null, exit, false, true);
                    } catch (e) {
                      // default withdraw gas: 230K + STANDARD ERC20 TRANFER + (siblings.lenght * 31K)
                      gasLimit = BigInt.from(GAS_LIMIT_WITHDRAW_DEFAULT);
                      exit.merkleProof.siblings.forEach((element) {
                        gasLimit += BigInt.from(GAS_LIMIT_WITHDRAW_SIBLING);
                      });
                      if (exit.token.id != 0) {
                        gasLimit += BigInt.from(GAS_STANDARD_ERC20_TX);
                      }
                    }

                    Navigator.of(widget.arguments.parentContext)
                        .pushNamed("/transaction_details",
                            arguments: TransactionDetailsArguments(
                              store: widget.arguments.store,
                              transactionType: TransactionType.WITHDRAW,
                              transactionLevel: TransactionLevel.LEVEL1,
                              status: TransactionStatus.DRAFT,
                              token: exit.token,
                              exit: exit,
                              amount: double.parse(exit.balance) /
                                  pow(10, exit.token.decimals),
                              addressFrom: addressFrom,
                              addressTo: addressTo,
                              gasLimit: gasLimit.toInt(),
                              gasPrice: gasPrice.toInt(),
                            ))
                        .then((value) => _onRefresh());
                  });
                } else if (i == 0 && pendingWithdraws.length > 0) {
                  final index = i;
                  final pendingWithdraw = pendingWithdraws[index];
                  final Token token = Token.fromJson(pendingWithdraw['token']);

                  final Exit exit = exits.firstWhere(
                      (exit) => exit.itemId == pendingWithdraw['itemId'],
                      orElse: () => Exit(
                          hezEthereumAddress:
                              pendingWithdraw['hermezEthereumAddress'],
                          token: token,
                          balance: pendingWithdraw['amount']
                              .toString()
                              .replaceAll('.0', '')));

                  final String currency = widget
                      .arguments.store.state.defaultCurrency
                      .toString()
                      .split('.')
                      .last;

                  int step = 2;
                  if (pendingWithdraw['status'] == 'pending') {
                    step = 3;
                  } else if (pendingWithdraw['status'] == 'fail') {
                    step = 2;
                  } else if (pendingWithdraw['status'] == 'initiated') {
                    step = 1;
                  }

                  return WithdrawalRow(
                    exit,
                    step,
                    currency,
                    widget.arguments.store.state.exchangeRatio,
                    step == 2
                        ? () async {
                            BigInt gasPrice = BigInt.one;
                            GasPriceResponse gasPriceResponse =
                                await widget.arguments.store.getGasPrice();
                            switch (widget.arguments.store.state.defaultFee) {
                              case WalletDefaultFee.SLOW:
                                int gasPriceFloor =
                                    gasPriceResponse.safeLow * pow(10, 8);
                                gasPrice = BigInt.from(gasPriceFloor);
                                break;
                              case WalletDefaultFee.AVERAGE:
                                int gasPriceFloor =
                                    gasPriceResponse.average * pow(10, 8);
                                gasPrice = BigInt.from(gasPriceFloor);
                                break;
                              case WalletDefaultFee.FAST:
                                int gasPriceFloor =
                                    gasPriceResponse.fast * pow(10, 8);
                                gasPrice = BigInt.from(gasPriceFloor);
                                break;
                            }

                            String addressFrom = exit.hezEthereumAddress;
                            String addressTo =
                                getCurrentEnvironment().contracts['Hermez'];

                            BigInt gasLimit = BigInt.from(GAS_LIMIT_HIGH);
                            final amountWithdraw = getTokenAmountBigInt(
                                double.parse(exit.balance) /
                                    pow(10, exit.token.decimals),
                                exit.token.decimals);
                            try {
                              gasLimit = await widget.arguments.store
                                  .withdrawGasLimit(
                                      amountWithdraw, null, exit, false, true);
                            } catch (e) {
                              gasLimit = BigInt.from(
                                  GAS_LIMIT_WITHDRAW_DEFAULT +
                                      (GAS_LIMIT_WITHDRAW_SIBLING *
                                          exit.merkleProof.siblings.length));
                              if (exit.token.id != 0) {
                                gasLimit += BigInt.from(GAS_STANDARD_ERC20_TX);
                              }
                            }
                            int offset = GAS_LIMIT_OFFSET;
                            gasLimit += BigInt.from(offset);
                            Navigator.of(widget.arguments.parentContext)
                                .pushNamed("/transaction_details",
                                    arguments: TransactionDetailsArguments(
                                      store: widget.arguments.store,
                                      transactionType: TransactionType.WITHDRAW,
                                      transactionLevel: TransactionLevel.LEVEL1,
                                      status: TransactionStatus.DRAFT,
                                      token: exit.token,
                                      exit: exit,
                                      amount: amountWithdraw.toDouble() /
                                          pow(10, exit.token.decimals),
                                      addressFrom: addressFrom,
                                      addressTo: addressTo,
                                      gasLimit: gasLimit.toInt(),
                                      gasPrice: gasPrice.toInt(),
                                    ))
                                .then((value) => _onRefresh());
                          }
                        : () {},
                    retry: true,
                  );
                } else {
                  Color statusColor = HermezColors.statusOrange;
                  Color statusBackgroundColor =
                      HermezColors.statusOrangeBackground;
                  var title = "";
                  var subtitle = "";
                  final index = i -
                      (pendingExits.isNotEmpty || exits.isNotEmpty //||
                          //_pendingWithdraws.isNotEmpty
                          ? 1
                          : 0);
                  dynamic element = transactions.elementAt(index);
                  var type = 'type';
                  var txType;
                  var status = 'status';
                  var timestamp = 0;
                  var txId;
                  var txHash;
                  var addressFrom = 'from';
                  var addressTo = 'to';
                  var value = '0';
                  if (element.runtimeType == ForgedTransaction) {
                    ForgedTransaction transaction = element;
                    if (transaction.id != null) {
                      txId = transaction.id;
                    }
                    if (transaction.type == "CreateAccountDeposit" ||
                        transaction.type == "Deposit") {
                      type = "DEPOSIT";
                      value = transaction.l1info.depositAmount.toString();
                      if (transaction.l1info.depositAmountSuccess == true) {
                        status = "CONFIRMED";
                        final formatter = DateFormat(
                            "yyyy-MM-ddThh:mm:ssZ"); // "2021-03-18T10:42:01Z"
                        final DateTime dateTimeFromStr =
                            formatter.parse(transaction.timestamp);
                        timestamp = dateTimeFromStr.millisecondsSinceEpoch;
                      } else if (transaction.timestamp.isNotEmpty) {
                        final formatter = DateFormat(
                            "yyyy-MM-ddThh:mm:ss"); // "2021-03-24T15:42:544802"
                        final DateTime dateTimeFromStr =
                            formatter.parse(transaction.timestamp);
                        timestamp = dateTimeFromStr.millisecondsSinceEpoch;
                        if (transaction.hash != null) {
                          txHash = transaction.hash;
                        }
                      }
                      addressFrom = getEthereumAddress(
                          transaction.fromHezEthereumAddress);
                      addressTo = transaction.fromHezEthereumAddress;
                    } else if (transaction.type == "Exit" ||
                        transaction.type == "ForceExit") {
                      type = "WITHDRAW";
                      value = transaction.amount.toString();
                      if (transaction.timestamp.isNotEmpty) {
                        status = "CONFIRMED";
                        final formatter = DateFormat(
                            "yyyy-MM-ddThh:mm:ssZ"); // "2021-03-18T10:42:01Z"
                        final DateTime dateTimeFromStr =
                            formatter.parse(transaction.timestamp);
                        timestamp = dateTimeFromStr.millisecondsSinceEpoch;
                      }
                      addressFrom = transaction.fromHezEthereumAddress;
                      addressTo = getEthereumAddress(
                          transaction.fromHezEthereumAddress);
                    } else if (transaction.type == "Transfer") {
                      value = transaction.amount.toString();
                      if (transaction.fromAccountIndex ==
                          widget.arguments.account.accountIndex) {
                        type = "SEND";
                        if (transaction.batchNum != null) {
                          status = "CONFIRMED";
                          final formatter = DateFormat(
                              "yyyy-MM-ddThh:mm:ssZ"); // "2021-03-18T10:42:01Z"
                          final DateTime dateTimeFromStr =
                              formatter.parse(transaction.timestamp);
                          timestamp = dateTimeFromStr.millisecondsSinceEpoch;
                        } else if (transaction.timestamp.isNotEmpty) {
                          final formatter = DateFormat(
                              "yyyy-MM-ddThh:mm:ss"); // "2021-03-24T15:42:544802"
                          final DateTime dateTimeFromStr =
                              formatter.parse(transaction.timestamp);
                          timestamp = dateTimeFromStr.millisecondsSinceEpoch;
                        }
                        addressFrom = transaction.fromHezEthereumAddress;
                        addressTo = transaction.toHezEthereumAddress;
                      } else if (transaction.toAccountIndex ==
                          widget.arguments.account.accountIndex) {
                        type = "RECEIVE";
                        if (transaction.timestamp.isNotEmpty) {
                          status = "CONFIRMED";
                          final formatter = DateFormat(
                              "yyyy-MM-ddThh:mm:ssZ"); // "2021-03-18T10:42:01Z"
                          final DateTime dateTimeFromStr =
                              formatter.parse(transaction.timestamp);
                          timestamp = dateTimeFromStr.millisecondsSinceEpoch;
                        }
                        addressFrom = transaction.fromHezEthereumAddress;
                        addressTo = transaction.toHezEthereumAddress;
                      }
                    }
                  } else {
                    LinkedHashMap event = element;
                    type = event['type'];
                    status = event['status'];
                    timestamp = event['timestamp'];
                    txHash = event['txHash'];
                    addressFrom = event['from'];
                    addressTo = event['to'];
                    value = event['value'];
                  }

                  final String currency = widget
                      .arguments.store.state.defaultCurrency
                      .toString()
                      .split('.')
                      .last;

                  String symbol = "";
                  if (currency == "EUR") {
                    symbol = "€";
                  } else if (currency == "CNY") {
                    symbol = "\¥";
                  } else {
                    symbol = "\$";
                  }

                  var amount = (getTokenAmountBigInt(
                              double.parse(value) /
                                  pow(10,
                                      widget.arguments.account.token.decimals),
                              widget.arguments.account.token.decimals)
                          .toDouble()) /
                      pow(10, widget.arguments.account.token.decimals);
                  var date = new DateTime.fromMillisecondsSinceEpoch(timestamp);
                  //var format = DateFormat('dd MMM');
                  var format = DateFormat('dd/MM/yyyy');
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
                      title = "Moved";
                      icon = "assets/tx_move.png";
                      isNegative = widget.arguments.store.state.txLevel ==
                          TransactionLevel.LEVEL2;
                      break;
                    case "DEPOSIT":
                      txType = TransactionType.DEPOSIT;
                      title = "Moved";
                      icon = "assets/tx_move.png";
                      isNegative = widget.arguments.store.state.txLevel ==
                          TransactionLevel.LEVEL1;
                      break;
                  }

                  TransactionStatus txStatus = TransactionStatus.CONFIRMED;
                  if (status == "CONFIRMED") {
                    subtitle = format.format(date);
                    txStatus = TransactionStatus.CONFIRMED;
                  } else if (status == "INVALID") {
                    subtitle = "Invalid";
                    statusColor = HermezColors.statusRed;
                    statusBackgroundColor = HermezColors.statusRedBackground;
                    txStatus = TransactionStatus.INVALID;
                  } else {
                    subtitle = "Pending";
                    txStatus = TransactionStatus.PENDING;
                  }

                  return Container(
                    child: ListTile(
                      leading: _getLeadingWidget(icon, null),
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
                      subtitle: status != "CONFIRMED"
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                  Container(
                                    padding: EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: statusBackgroundColor
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(subtitle,
                                        // On Hold, Pending
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 16,
                                          fontFamily: 'ModernEra',
                                          fontWeight: FontWeight.w500,
                                        )),
                                  )
                                ])
                          : Container(
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
                              padding: EdgeInsets.all(5.0),
                              child: Text(
                                EthAmountFormatter.formatAmount(amount,
                                    widget.arguments.account.token.symbol),
                                style: TextStyle(
                                  color: HermezColors.black,
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
                                (isNegative ? "- " : "") +
                                    symbol +
                                    (amount *
                                            widget.arguments.account.token.USD *
                                            (currency != 'USD'
                                                ? widget.arguments.store.state
                                                    .exchangeRatio
                                                : 1))
                                        .toStringAsFixed(2),
                                style: TextStyle(
                                  color: isNegative
                                      ? HermezColors.blueyGreyTwo
                                      : HermezColors.green,
                                  fontSize: 16,
                                  fontFamily: 'ModernEra',
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ]),
                      onTap: () async {
                        Navigator.pushNamed(context, "transaction_details",
                                arguments: TransactionDetailsArguments(
                                    store: widget.arguments.store,
                                    transactionType: txType,
                                    transactionLevel:
                                        widget.arguments.store.state.txLevel,
                                    status: txStatus,
                                    account: widget.arguments.account,
                                    token: widget.arguments.account.token,
                                    amount: amount,
                                    transactionId: txId,
                                    transactionHash: txHash,
                                    addressFrom: addressFrom,
                                    addressTo: addressTo,
                                    transactionDate: date))
                            .then((value) => _onRefresh());
                      },
                    ),
                  );
                }
              }),
          onRefresh: _onRefresh,
        ),
      );
    }
  }

  Future<void> fetchData() async {
    if (widget.arguments.store.state.txLevel == TransactionLevel.LEVEL2) {
      poolTxs =
          await fetchPoolTransactions(widget.arguments.account.accountIndex);
      final List<ForgedTransaction> pendingPoolTxs =
          poolTxs.map((poolTransaction) {
        return ForgedTransaction(
            id: poolTransaction.id,
            amount: poolTransaction.amount,
            type: poolTransaction.type,
            fromHezEthereumAddress: poolTransaction.fromHezEthereumAddress,
            fromAccountIndex: poolTransaction.fromAccountIndex,
            toAccountIndex: poolTransaction.toAccountIndex,
            toHezEthereumAddress: poolTransaction.toHezEthereumAddress,
            timestamp: poolTransaction.timestamp);
      }).toList();
      pendingExits =
          await fetchPendingExits(widget.arguments.account.accountIndex);
      exits = await fetchExits(widget.arguments.account.token.id);
      filteredExits = exits.toList();
      pendingWithdraws =
          await fetchPendingWithdraws(widget.arguments.account.token.id);
      filteredExits.removeWhere((Exit exit) {
        for (dynamic pendingWithdraw in pendingWithdraws) {
          if (pendingWithdraw["id"] ==
              (exit.accountIndex + exit.batchNum.toString())) {
            return true;
          }
        }
        return false;
      });
      pendingDeposits =
          await fetchPendingDeposits(widget.arguments.account.token.id);
      final List<ForgedTransaction> pendingDepositsTxs =
          pendingDeposits.map((pendingDeposit) {
        return ForgedTransaction(
            id: pendingDeposit['id'],
            hash: pendingDeposit['hash'],
            l1info: L1Info(depositAmount: pendingDeposit['amount'].toString()),
            type: pendingDeposit['type'],
            fromHezEthereumAddress: pendingDeposit['fromHezEthereumAddress'],
            timestamp: pendingDeposit['timestamp']);
      }).toList();
      if (transactions.isEmpty) {
        transactions.addAll(pendingPoolTxs);
        transactions.addAll(pendingDepositsTxs);
      }
      List<dynamic> historyTransactions = await fetchHistoryTransactions();
      final filteredTransactions = filterExitsFromHistoryTransactions(
        historyTransactions,
        exits,
      );
      setState(() {
        pendingItems = pendingItems;
        fromItem = filteredTransactions.last.itemId;
        transactions.addAll(filteredTransactions);
        _isLoading = false;
      });
    } else {
      pendingDeposits =
          await fetchPendingDeposits(widget.arguments.account.token.id);
      final List<ForgedTransaction> pendingDepositsTxs =
          pendingDeposits.map((pendingDeposit) {
        return ForgedTransaction(
            id: pendingDeposit['id'],
            hash: pendingDeposit['hash'],
            l1info: L1Info(depositAmount: pendingDeposit['amount'].toString()),
            type: pendingDeposit['type'],
            fromHezEthereumAddress: pendingDeposit['fromHezEthereumAddress'],
            timestamp: pendingDeposit['timestamp']);
      }).toList();
      List<dynamic> historyTransactions = await fetchHistoryTransactions();
      if (transactions.isEmpty) {
        for (ForgedTransaction forgedTransaction in pendingDepositsTxs) {
          historyTransactions.firstWhere(
              (element) => element['txHash'] == forgedTransaction.hash,
              orElse: () => transactions.add(forgedTransaction));
        }
      }
      widget.arguments.account = await fetchAccount();
      setState(() {
        pendingItems = 0;
        transactions.addAll(historyTransactions);
        _isLoading = false;
      });
    }
  }

  void fetchState() {
    widget.arguments.store.getState();
  }

  Future<Account> fetchAccount() {
    if (widget.arguments.store.state.txLevel == TransactionLevel.LEVEL2) {
      return widget.arguments.store
          .getAccount(widget.arguments.account.accountIndex);
    } else {
      return widget.arguments.store
          .getL1Account(widget.arguments.account.token.id);
    }
  }

  Future<List<dynamic>> fetchPoolTransactions(String accountIndex) async {
    List<PoolTransaction> poolTxs =
        await widget.arguments.store.getPoolTransactions(accountIndex);
    poolTxs.removeWhere((transaction) => transaction.type == 'Exit');
    return poolTxs;
  }

  Future<List<dynamic>> fetchPendingDeposits(int tokenId) async {
    final accountPendingDeposits =
        await widget.arguments.store.getPendingDeposits();
    accountPendingDeposits.removeWhere((pendingDeposit) =>
        Token.fromJson(pendingDeposit['token']).id != tokenId);
    return accountPendingDeposits;
  }

  Future<List<dynamic>> fetchPendingExits(String accountIndex) async {
    List<PoolTransaction> poolTxs =
        await widget.arguments.store.getPoolTransactions(accountIndex);
    poolTxs.removeWhere((transaction) => transaction.type != 'Exit');
    return poolTxs;
  }

  Future<List<Exit>> fetchExits(int tokenId) {
    return widget.arguments.store.getExits(tokenId: tokenId);
  }

  Future<List<dynamic>> fetchPendingWithdraws(int tokenId) async {
    final accountPendingWithdraws =
        await widget.arguments.store.getPendingWithdraws();
    accountPendingWithdraws.removeWhere((pendingWithdraw) =>
        Token.fromJson(pendingWithdraw['token']).id != tokenId);
    return accountPendingWithdraws;
  }

  Future<List<dynamic>> fetchHistoryTransactions() async {
    if (widget.arguments.store.state.txLevel == TransactionLevel.LEVEL1) {
      return await widget.arguments.store.getEthereumTransactionsByAddress(
          widget.arguments.store.state.ethereumAddress,
          widget.arguments.account.token,
          fromItem);
    } else {
      final transactionsResponse = await widget.arguments.store
          .getHermezTransactionsByAddress(
              widget.arguments.store.state.ethereumAddress,
              widget.arguments.account,
              fromItem);
      pendingItems = transactionsResponse.pendingItems;
      return transactionsResponse.transactions;
    }
  }

  List<ForgedTransaction> filterExitsFromHistoryTransactions(
      List<ForgedTransaction> historyTransactions, List<Exit> exits) {
    List<ForgedTransaction> filteredTransactions =
        List.from(historyTransactions);
    filteredTransactions.removeWhere((ForgedTransaction transaction) {
      if (transaction.type == 'Exit') {
        Exit exitTx;
        exits.forEach((Exit exit) {
          if (exit.batchNum == transaction.batchNum &&
              exit.accountIndex == transaction.fromAccountIndex) {
            exitTx = exit;
          }
        });

        if (exitTx != null) {
          if (exitTx.instantWithdraw != null ||
              exitTx.delayedWithdraw != null) {
            return false;
          } else {
            return true;
          }
        }
      }

      return false;
    });
    return filteredTransactions;
  }

  /*Future<Account> getEthereumAccount() async {
    Account ethereumAccount = await widget.arguments.store.getL1Account(0);
    return ethereumAccount;
  }*/

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // takes in an object and color and returns a circle avatar with first letter and required color
  CircleAvatar _getLeadingWidget(String icon, Color color) {
    return new CircleAvatar(
        radius: 23, backgroundColor: color, child: Image.asset(icon));
  }
}
