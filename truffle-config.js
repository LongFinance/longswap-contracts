//const HDWalletProvider = require("truffle-hdwallet-provider");
const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  // Uncommenting the defaults below
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  //
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider("", "https://ropsten.infura.io/v3/f09a2a241d304d83b48af7bd01fce0ea")
      },
      network_id: 3,
      gas: 5500000,      //make sure this gas allocation isn't over 4M, which is the max
      skipDryRun: true
    },
  //  test: {
  //    host: "127.0.0.1",
  //    port: 7545,
  //    network_id: "*"
  //  }
  },
  compilers: {
    solc: {
      version: "0.6.12"
    }
  }
};
