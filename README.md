# *Knowhere Name service(.kid)*
### Introduction
<p>"Knowhere Name Service" is a domain name system developed based on blockchain. The main role is to map readable names of class alice.kid to wallet addresses on multiple chains such as Ethereum, Bitcoin, etc., while supporting reverse resolution.

KID and DNS have similarities in architecture, the root domain name will exist in the registry contract in KID. Users are assigned based on the root domain name in the registration process and can register second-level domain names based on the first-level domain name they hold to extend the use of scenarios.</p>

### Overview
<p>The “Knowhere Name Service” domain name system uses the ERC721 protocol to bind domain names to NFTs in order to increase liquidity in the marketplace.
The format requirements for domain name registration comply with UTS-46 domain name registration rules, that is, they support lowercase letters, numbers, as well as underscores and additional middle strikes, and can be mixed with upper and lowercase letters during user registration and use. The tool contract will help users automatically convert lowercase, check uniqueness after conversion during registration, and use the converted domain name resolution.
</p>

### The standard protocol/libs used are as follows:
* ERC-721 Non-Fungible Token Protocol.
* ERC-721 proposal for off-chain signature and on-chain verification of data.
* EIP 127 NameHash proposal, complete with hierarchical calculations layer and hashing in the contract.
<p>NameHash is a recursive algorithm process that generates a unique hash for every valid domain names, such as "alice. kid". The hash of the hierarchical domain can be derived downwards, e.g. "pay.alice.kid", and the hash of the first-level domain also can be derived upwards. It is this property that helps KID create a hierarchical system. Complete domain name, e.g. pay.alice.kid:
"pay" "alice" "kid" all belong to the “Label”, we recursively hash the label layer by layer until all the label hash values are generated. Symbols that are only separators in the "domain hash calculation" process are not calculated. So for the above domain ["pay", "rice", "kid"], we will use the following algorithm for the output hash.

namehash([]) = 0x0000000000000000000000000000000000000000000000000000000000000000  
namehash([label, …]) = keccak256(namehash(…), keccak256(label))</p>

* Extended UTS46 contracts to help users with registration and resolution.
* StringUtil validates zero-width characters and calculates domain length.

### Contract content
<p>The domain name system currently mainly includes KID registry, KID resolver, Price-oracle for public contracts. The domain name registry contract inherits the ERC721 standard and completes the extension of the registration process. The resolver contract mainly helps users to complete domain name resolution, and allows users to customize resolver contracts. However, to implement some of the methods in the IResolver interface, the current domain name resolver address can be redirected to a custom resolver contract in the registry.</p>

### Domain Registration
* Generate token id with string type field and mint the corresponding NFTs.
* The user can use the methods in the registry to check whether the name to be registered is being used.
* Using casting method to complete NFTs minting and domain name registration at the same time.
* Note: Support free mint on public chains based on Ethereum currently.

## Domain name resolution
* The contract allows to get all the resolution data set in the specific token in the form of token id/domain name.
* After own the KID, please set up the data before using it. There are two ways to add data in the resolver contract as follows:
1).Once chain and once address for once setting.
2).Multiple chains and multiple corresponding addresses for batch setting.
