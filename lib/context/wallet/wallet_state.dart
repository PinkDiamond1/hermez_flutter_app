import 'package:hermez/model/wallet.dart';
import 'package:hermez/screens/transaction_amount.dart';
import 'package:hermez_plugin/model/account.dart';
import 'package:hermez_plugin/model/exit.dart';
import 'package:hermez_plugin/model/pool_transaction.dart';

abstract class WalletAction {}

class InitialiseWallet extends WalletAction {
  InitialiseWallet(this.address, this.privateKey);
  final String address;
  final String privateKey;
}

class BalanceUpdated extends WalletAction {
  BalanceUpdated(this.ethBalance, this.tokensBalance, this.cryptoList);
  final BigInt ethBalance;
  final Map<String, BigInt> tokensBalance;
  final List cryptoList;
}

class UpdatingBalance extends WalletAction {}

// TODO use this

class WalletUpdated extends WalletAction {
  WalletUpdated(
    this.l1Accounts,
    this.l2Accounts,
    this.exits,
    this.pendingL2Txs,
    this.pendingDeposits,
    this.pendingWithdraws,
    this.pendingForceExits,
    /*
      this.pendingL1Txs, this.pendingForceExits*/
  );
  final List<Account> l1Accounts;
  final List<Account> l2Accounts;
  final List<Exit> exits;
  final List<PoolTransaction> pendingL2Txs;
  final List<dynamic> pendingDeposits;
  final List<dynamic> pendingWithdraws;
  final List<dynamic> pendingForceExits;

  /*final List<dynamic> pendingL1Txs;
  final List<dynamic> pendingForceExits;
  */
}

class UpdatingWallet extends WalletAction {}

class DefaultCurrencyUpdated extends WalletAction {
  DefaultCurrencyUpdated(this.defaultCurrency);
  final WalletDefaultCurrency defaultCurrency;
}

class DefaultFeeUpdated extends WalletAction {
  DefaultFeeUpdated(this.defaultFee);
  final WalletDefaultFee defaultFee;
}

class ExchangeRatioUpdated extends WalletAction {
  ExchangeRatioUpdated(this.exchangeRatio);
  final double exchangeRatio;
}

class LevelUpdated extends WalletAction {
  LevelUpdated(this.txLevel);
  final TransactionLevel txLevel;
}

// transaction

class TransactionStarted extends WalletAction {}

class TransactionFinished extends WalletAction {}

Wallet reducer(Wallet state, WalletAction action) {
  if (action is InitialiseWallet) {
    return state.rebuild((b) => b
      ..ethereumAddress = action.address
      ..ethereumPrivateKey = action.privateKey);
  }

  if (action is UpdatingBalance) {
    return state.rebuild((b) => b..loading = true);
  }

  if (action is BalanceUpdated) {
    return state.rebuild((b) => b
      ..loading = false
      ..ethBalance = action.ethBalance
      ..tokensBalance = action.tokensBalance
      ..cryptoList = action.cryptoList);
  }

  if (action is UpdatingWallet) {
    return state.rebuild((b) => b..loading = true);
  }

  if (action is WalletUpdated) {
    return state.rebuild((b) => b
      ..loading = false
      ..l1Accounts = action.l1Accounts
      ..l2Accounts = action.l2Accounts
      ..exits = action.exits
      ..pendingL2Txs = action.pendingL2Txs
      ..pendingDeposits = action.pendingDeposits
      ..pendingWithdraws = action.pendingWithdraws
      ..pendingForceExits = action.pendingForceExits);
  }

  if (action is DefaultCurrencyUpdated) {
    return state.rebuild((b) => b..defaultCurrency = action.defaultCurrency);
  }

  if (action is DefaultFeeUpdated) {
    return state.rebuild((b) => b..defaultFee = action.defaultFee);
  }

  if (action is ExchangeRatioUpdated) {
    return state.rebuild((b) => b..exchangeRatio = action.exchangeRatio);
  }

  if (action is LevelUpdated) {
    return state.rebuild((b) => b..txLevel = action.txLevel);
  }

  if (action is TransactionStarted) {
    return state.rebuild((b) => b..loading = true);
  }

  if (action is TransactionFinished) {
    return state.rebuild((b) => b..loading = false);
  }

  return state;
}
