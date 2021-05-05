import 'dart:async';
import 'dart:typed_data';

import 'package:hermez_plugin/addresses.dart' as addresses;
import 'package:hermez_plugin/api.dart' as api;
import 'package:hermez_plugin/api.dart';
import 'package:hermez_plugin/constants.dart';
import 'package:hermez_plugin/hermez_compressed_amount.dart';
import 'package:hermez_plugin/hermez_wallet.dart';
import 'package:hermez_plugin/model/account.dart';
import 'package:hermez_plugin/model/coordinator.dart';
import 'package:hermez_plugin/model/create_account_authorization.dart';
import 'package:hermez_plugin/model/exit.dart';
import 'package:hermez_plugin/model/exits_request.dart';
import 'package:hermez_plugin/model/forged_transaction.dart';
import 'package:hermez_plugin/model/forged_transactions_request.dart';
import 'package:hermez_plugin/model/forged_transactions_response.dart';
import 'package:hermez_plugin/model/pool_transaction.dart';
import 'package:hermez_plugin/model/recommended_fee.dart';
import 'package:hermez_plugin/model/state_response.dart';
import 'package:hermez_plugin/model/token.dart';
import 'package:hermez_plugin/model/tokens_request.dart';
import 'package:hermez_plugin/model/transaction.dart';
import 'package:hermez_plugin/tx.dart' as tx;
import 'package:hermez_plugin/tx_utils.dart';
import 'package:web3dart/web3dart.dart' as web3;

import 'configuration_service.dart';

abstract class IHermezService {
  Future<StateResponse> getState();
  Future<bool> authorizeAccountCreation(
      web3.EthereumAddress ethereumAddress, String bjj, String signature);
  Future<CreateAccountAuthorization> getCreateAccountAuthorization(
      web3.EthereumAddress ethereumAddress);
  Future<List<Account>> getAccounts(
      web3.EthereumAddress ethereumAddress, List<int> tokenIds,
      {int fromItem = 0,
      PaginationOrder order = PaginationOrder.ASC,
      int limit = DEFAULT_PAGE_SIZE});
  Future<Account> getAccount(String accountIndex);
  Future<List<Exit>> getExits(web3.EthereumAddress ethereumAddress);
  Future<List<Coordinator>> getCoordinators(
      String forgerAddr, String bidderAddr);
  Future<ForgedTransactionsResponse> getForgedTransactions(
      ForgedTransactionsRequest request);
  Future<ForgedTransaction> getTransactionById(String transactionId);
  Future<PoolTransaction> getPoolTransactionById(String transactionId);
  Future<List<Token>> getTokens();
  Future<Token> getTokenById(int tokenId);
  Future<bool> deposit(BigInt amount, String hezEthereumAddress, Token token,
      String babyJubJub, String privateKey,
      {int gasLimit = GAS_LIMIT_HIGH, int gasPrice = GAS_MULTIPLIER});
  Future<bool> withdraw(
      BigInt amount,
      Account account,
      Exit exit,
      bool completeDelayedWithdrawal,
      bool instantWithdrawal,
      String hezEthereumAddress,
      String babyJubJub,
      String privateKey,
      {int gasLimit = GAS_LIMIT,
      int gasMultiplier = GAS_MULTIPLIER});
  Future<bool> forceExit(BigInt amount, Account account, String privateKey,
      {int gasLimit = GAS_LIMIT, int gasMultiplier = GAS_MULTIPLIER});
  Future<bool> generateAndSendL2Tx(
      Map transaction, HermezWallet wallet, Token token);
  Future<bool> sendL2Transaction(Transaction transaction, String bjj);
  Future<RecommendedFee> getRecommendedFee();
}

class HermezService implements IHermezService {
  final web3.Web3Client client;
  IConfigurationService _configService;
  HermezService(this.client, this._configService);

  @override
  Future<StateResponse> getState() async {
    final StateResponse state = await api.getState();
    final baseApiUrl = state.network.nextForgers[0].coordinator.URL;
    Uri uri = Uri.parse(baseApiUrl);

    api.setBaseApiUrl(uri.host);
    return state;
  }

  @override
  Future<bool> authorizeAccountCreation(web3.EthereumAddress ethereumAddress,
      String bjj, String signature) async {
    final response = await api.postCreateAccountAuthorization(
        addresses.getHermezAddress(ethereumAddress.hex), bjj, signature);
    if (response != null) {
      return response.statusCode == 200;
    } else {
      return false;
    }
  }

  @override
  Future<CreateAccountAuthorization> getCreateAccountAuthorization(
      web3.EthereumAddress ethereumAddress) async {
    final response = await api.getCreateAccountAuthorization(
        addresses.getHermezAddress(ethereumAddress.hex));
    return response;
  }

  @override
  Future<List<Account>> getAccounts(
      web3.EthereumAddress ethereumAddress, List<int> tokenIds,
      {int fromItem = 0,
      PaginationOrder order = PaginationOrder.ASC,
      int limit = DEFAULT_PAGE_SIZE}) async {
    final accountsResponse = await api.getAccounts(
        addresses.getHermezAddress(ethereumAddress.hex), tokenIds,
        fromItem: fromItem, order: order, limit: limit);
    return accountsResponse.accounts;
  }

  @override
  Future<Account> getAccount(String accountIndex) async {
    final response = await api.getAccount(accountIndex);
    return response;
  }

  @override
  Future<List<Token>> getTokens() async {
    final TokensRequest tokensRequest = null;
    final tokensResponse = await api.getTokens(
        tokenIds: tokensRequest != null ? tokensRequest.ids : List());
    return tokensResponse.tokens;
  }

  @override
  Future<Token> getTokenById(int tokenId) async {
    final tokenResponse = await api.getToken(tokenId);
    return tokenResponse;
  }

  @override
  Future<ForgedTransactionsResponse> getForgedTransactions(
      ForgedTransactionsRequest request) async {
    final response = await api.getTransactions(
        accountIndex: request.accountIndex,
        fromItem: request.fromItem,
        order: api.PaginationOrder.DESC);
    return response;
  }

  @override
  Future<ForgedTransaction> getTransactionById(String transactionId) async {
    final response = await api.getHistoryTransaction(transactionId);
    return response;
  }

  @override
  Future<PoolTransaction> getPoolTransactionById(String transactionId) async {
    final response = await api.getPoolTransaction(transactionId);
    return response;
  }

  @override
  Future<bool> generateAndSendL2Tx(
      Map transaction, HermezWallet wallet, Token token) async {
    final l2TxResult = tx.generateAndSendL2Tx(transaction, wallet, token);
    return l2TxResult != null;
  }

  @override
  Future<bool> sendL2Transaction(Transaction transaction, String bjj) async {
    final response = await tx.sendL2Transaction(transaction.toJson(), bjj);
    return response.isNotEmpty;
  }

  @override
  Future<List<Exit>> getExits(web3.EthereumAddress ethereumAddress,
      {bool onlyPendingWithdraws = true, int tokenId = -1}) async {
    ExitsRequest exitsRequest = new ExitsRequest(
        hezEthereumAddress: addresses.getHermezAddress(ethereumAddress.hex),
        onlyPendingWithdraws: onlyPendingWithdraws,
        tokenId: tokenId);
    final exitsResponse = await api.getExits(exitsRequest.hezEthereumAddress,
        exitsRequest.onlyPendingWithdraws, exitsRequest.tokenId);
    return exitsResponse.exits;
  }

  @override
  Future<Exit> getExit(int batchNum, String accountIndex) async {
    final exitResponse = await api.getExit(batchNum, accountIndex);
    return exitResponse;
  }

  @override
  Future<RecommendedFee> getRecommendedFee() async {
    final StateResponse state = await api.getState();
    return state.recommendedFee;
  }

  @override
  Future<List<Coordinator>> getCoordinators(
      String forgerAddr, String bidderAddr) async {}

  /// Makes a deposit.
  /// It detects if it's a 'createAccountDeposit' or a 'deposit' and prepares the parameters accordingly.
  /// Detects if it's an Ether, ERC 20 or ERC 777 token and sends the transaction accordingly.
  /// @param {BigInt} amount - The amount to be deposited
  /// @param {String} hezEthereumAddress - The Hermez address of the transaction sender
  /// @param {Object} token - The token information object as returned from the API
  /// @param {String} babyJubJub - The compressed BabyJubJub in hexadecimal format of the transaction sender.
  /// @param {String} providerUrl - Network url (i.e, http://localhost:8545). Optional
  /// @param {Object} signerData - Signer data used to build a Signer to send the transaction
  /// @param {Number} gasLimit - Optional gas limit
  /// @param {Number} gasMultiplier - Optional gas multiplier
  /// @returns {Promise} transaction parameters
  @override
  Future<bool> deposit(BigInt amount, String hezEthereumAddress, Token token,
      String babyJubJub, String privateKey,
      {int gasLimit = GAS_LIMIT_HIGH, int gasPrice = GAS_MULTIPLIER}) async {
    final txHash = await tx
        .deposit(HermezCompressedAmount.compressAmount(amount.toDouble()),
            hezEthereumAddress, token, babyJubJub, client, privateKey,
            gasLimit: gasLimit, gasPrice: gasPrice)
        .then((txHash) async {
      if (txHash != null) {
        await api.getAccounts(hezEthereumAddress, [token.id]).then((res) {
          _configService.addPendingDeposit({
            'hash': txHash,
            'fromHezEthereumAddress': hezEthereumAddress,
            'toHezEthereumAddress': hezEthereumAddress,
            'token': token,
            'amount': amount.toDouble(),
            'state': 'pend',
            'timestamp': DateTime.now().toIso8601String(),
            'type':
                res != null && res.accounts != null && res.accounts.length > 0
                    ? TxType.Deposit.toString().split('.').last
                    : TxType.CreateAccountDeposit.toString().split('.').last
          });
        });
      }
      return txHash != null;
    });
    return txHash;
  }

  Future<Uint8List> signDeposit(BigInt amount, String hezEthereumAddress,
      Token token, String babyJubJub, String privateKey,
      {int gasLimit = GAS_LIMIT, int gasMultiplier = GAS_MULTIPLIER}) async {
    final Uint8List signed = await tx.signDeposit(
        HermezCompressedAmount.compressAmount(amount.toDouble()),
        hezEthereumAddress,
        token,
        babyJubJub,
        client,
        privateKey);
    return signed;
  }

  @override
  Future<bool> withdraw(
      BigInt amount,
      Account account,
      Exit exit,
      bool completeDelayedWithdrawal,
      bool instantWithdrawal,
      String hezEthereumAddress,
      String babyJubJub,
      String privateKey,
      {int gasLimit = GAS_LIMIT,
      int gasMultiplier = GAS_MULTIPLIER}) async {
    final withdrawalId = exit.accountIndex + exit.batchNum.toString();

    if (completeDelayedWithdrawal == null ||
        completeDelayedWithdrawal == false) {
      try {
        bool isIntant = instantWithdrawal == null ? true : instantWithdrawal;
        await tx
            .withdraw(
                amount,
                exit.accountIndex,
                exit.token,
                babyJubJub,
                BigInt.from(exit.batchNum),
                exit.merkleProof.siblings,
                client,
                privateKey,
                isInstant: isIntant)
            .then((value) async => {
                  if (isIntant)
                    {
                      _configService.addPendingWithdraw({
                        'hermezEthereumAddress': hezEthereumAddress,
                        'id': withdrawalId,
                        'accountIndex': exit.accountIndex,
                        'batchNum': exit.batchNum,
                        'amount': amount.toDouble(),
                        'token': exit.token.toJson()
                      })
                    }
                  else
                    {
                      _configService.addPendingDelayedWithdraw({
                        'id': withdrawalId,
                        'accountIndex': exit.accountIndex,
                        'batchNum': exit.batchNum,
                        'instant': false,
                        'date': DateTime.now(),
                        'amount': amount,
                        'token': exit.token
                      })
                    }
                });
        return true;
      } catch (error) {
        print(error);
      }
    } else {
      try {
        tx.delayedWithdraw(hezEthereumAddress, account.token, client).then(
            (value) async =>
                {_configService.removePendingDelayedWithdraw(withdrawalId)});
      } catch (error) {
        print(error);
      }
    }
  }

  @override
  Future<bool> forceExit(BigInt amount, Account account, String privateKey,
      {int gasLimit = GAS_LIMIT, int gasMultiplier = GAS_MULTIPLIER}) async {
    return tx.forceExit(
        HermezCompressedAmount.compressAmount(amount.toDouble()),
        account.accountIndex,
        account.token,
        client,
        privateKey);
  }
}
