import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hermez/app_config.dart';
import 'package:hermez/service/address_service.dart';
import 'package:hermez/service/configuration_service.dart';
import 'package:hermez/service/contract_service.dart';
import 'package:hermez/service/exchange_service.dart';
import 'package:hermez/service/explorer_service.dart';
import 'package:hermez/service/hermez_service.dart';
import 'package:hermez/service/storage_service.dart';
import 'package:hermez_plugin/environment.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web_socket_channel/io.dart';

Future<List<SingleChildWidget>> createProviders(
    AppConfigParams params, EnvParams hermezParams) async {
  final client = Web3Client(hermezParams.baseWeb3Url, Client(),
      enableBackgroundIsolate: true, socketConnector: () {
    return IOWebSocketChannel.connect(hermezParams.baseWeb3RdpUrl)
        .cast<String>();
  });

  final localStorage = await SharedPreferences.getInstance();
  final secureStorage = new FlutterSecureStorage();
  final storageService = StorageService(localStorage, secureStorage);
  final configurationService =
      ConfigurationService(localStorage, secureStorage, storageService);
  final addressService = AddressService(configurationService);
  final hermezService = HermezService(client, configurationService);
  final exchangeService =
      ExchangeService(params.exchangeHttpUrl, params.exchangeApiKey);
  final contractService =
      ContractService(client, configurationService, params.ethGasPriceHttpUrl);
  final explorerService = ExplorerService(
      hermezParams.etherscanApiUrl, hermezParams.etherscanApiKey);

  return [
    Provider.value(value: addressService),
    Provider.value(value: contractService),
    Provider.value(value: explorerService),
    Provider.value(value: storageService),
    Provider.value(value: configurationService),
    Provider.value(value: hermezService),
    Provider.value(value: exchangeService)
  ];
}
