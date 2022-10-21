// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Domain } from "./libraries/Domain.sol";
import { StringUtil } from "./libraries/StringUtil.sol";
import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { SignatureChecker } from "./libraries/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IKNSRegistry } from "./interfaces/IKNSRegistry.sol";
import { UTS46 } from "./interfaces/UTS46.sol";

contract KNSRegistry is ERC721Burnable,IKNSRegistry,UTS46{

    using StringUtil for *;
    using EnumerableSet for EnumerableSet.UintSet;  
    using Domain for Domain.DomainContent;
    uint256 constant public KID_ROOT_HASH = 0x948a4d980a3cb6f520466227816cddc4165c85a49b8caa4c31c65f746080d1f2;
    mapping (uint256 => EnumerableSet.UintSet) private _domainTokenIds;
    mapping(uint256 => address) _domainResolver;
    mapping(uint256 => uint256) expirationTime;
    mapping(uint256 => string) public  tokenChars;
    mapping(bytes32 => uint256) public charsToId; 
    uint256 public constant GRACE_PERIOD = 90;
    bytes32 immutable public DOMAIN_SEPARATOR;
    bytes   public table;
    address feeRecipient;
    address public priceOracle;
    address public resolver;
    uint256 public minExpiration = 365;
    address permitAddress = 0x9add88207AC0Db396d6050716BADB7eC6C96bA33;
    address manager;
    uint    minLength = 3;
    uint    public totalSupply;
    //_table:0x4142434445464748494a4b4c4d4e4f505152535455565758595a6162636465666768696a6b6c6d6e6f707172737475767778797a
    constructor(address _priceOracle,address _feeRecipient,address _resolver,address _permit,bytes memory _table)ERC721("Knowhere Name Service (.kid)","KID"){
        //EIP712 domain_separator,Calculate and set domain segmentation
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,//keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
            0xd6dca49fdb49c705e715bbe969bf3d8b3bbace778a929b72fa3032887c5fda63,//keccak256("KNSRegistry")
            0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6,//keccak256(bytes("1"))
            block.chainid,
            address(this)
        ));
        priceOracle = _priceOracle;
        feeRecipient = _feeRecipient;  
        resolver = _resolver;
        permitAddress = _permit;
        table = _table;
        _mint(address(this), KID_ROOT_HASH);
        tokenChars[KID_ROOT_HASH] = "kid";
        manager = msg.sender;
    }

    function updatePermitInfo(address _fee,address _permit,uint _length) external {
        require(manager == msg.sender,"Not permitted");
        feeRecipient = _fee;
        permitAddress = _permit;
        minLength = _length;
    }

    function updateBaseAddress(address _price,address _resolver) external{
        require(manager == msg.sender,"Not permitted");
        priceOracle = _price;
        resolver = _resolver;
    }

    modifier onlyApprovedOrOwner(uint256 tokenId){
        require(isApprovedOrOwner(_msgSender(),tokenId));
        _;
    }

    function isApprovedOrOwner(address account, uint256 tokenId) public override view returns(bool)  {
        return _isApprovedOrOwner(account, tokenId);
    }

    function isExist(uint256 tokenId,string memory label) public override view returns(bool){
        uint256 identity = makeIdentity(tokenId, label);
        require(_getSupport(_getCodeResult(table,label)),"The registration conditions are not met");
        
        // return _exists(identity) && expirationTime[identity] + GRACE_PERIOD * 86400 > block.timestamp;
        return _exists(identity) && timeHelper(identity) > block.timestamp;
    }

    function makeIdentity(uint256 tokenId,string memory label) public override view returns(uint256){
        bytes memory result = _getCodeResult(table,label);
        require (bytes(label).length > minLength && _getSupport(result) && StringUtil.valid(label),
        "The label does not meet the requirements");
        return uint256(keccak256(
            abi.encodePacked(tokenId, 
            keccak256(abi.encodePacked(result)))
        ));
    }

    function safeMintDomain(Domain.DomainContent calldata content) external override payable{
        require(StringUtil.dotCount(content.label) == 0,"Separator is not allowed");
        require(_exists(content.tokenId),"Token id does not exist");
        require(timeHelper(content.tokenId) > block.timestamp,"Invalid domain");
        if(content.tokenId != KID_ROOT_HASH){
            require(isApprovedOrOwner(content.holder, content.tokenId),"No permission to mint under the current id");
        }
        require(_validateContent(content,Domain.getDomainHash(content)),"Data validation failed");
        require(content.expiration >= minExpiration,"Minimum registration period: 1 year");
        if(content.whitelisted){
            require(content.expiration == minExpiration,"The white list can only be used for one year for free");
        }
        _safeMintDomain(content);
    }

    function _validateContent(Domain.DomainContent calldata content,bytes32 contentHash) public view returns(bool){
        return SignatureChecker.verify(contentHash, permitAddress, content.v, content.r, content.s, DOMAIN_SEPARATOR);
    }

    function safeTransferETH(address to, uint value) private {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }

    function _safeMintDomain(Domain.DomainContent calldata content) internal {
        if(!content.whitelisted && content.tokenId == KID_ROOT_HASH){
            uint price = IPriceOracle(priceOracle).getPrice(content.label, content.expiration);
            require(price > 0 && msg.value >= price,"Price error");
            safeTransferETH(feeRecipient, msg.value);
        }
        uint256 identity = makeIdentity(content.tokenId, content.label);
        bytes memory _newUri = abi.encodePacked(string(_getCodeResult(table,content.label)), ".", tokenChars[content.tokenId]);
        _domainTokenIds[content.tokenId].add(identity);    
        
        if(_exists(identity) && expirationTime[identity] + GRACE_PERIOD * 86400 < block.timestamp){
            _burnDomain(content.tokenId, content.label);
        }
        if (bytes(content.data).length != 0) {
            _safeMint(content.holder, identity, content.data);
        } else {
            _mint(content.holder, identity);
        }
        if(content.tokenId == KID_ROOT_HASH) expirationTime[identity] = block.timestamp + content.expiration * 86400;
        tokenChars[identity] = string(_newUri);
        charsToId[keccak256(abi.encodePacked(string(_newUri)))] = identity;
        _domainResolver[identity] = resolver;
        totalSupply += 1;
        uint payType;
        if(content.whitelisted) payType = 1;
        emit CreateDomain(identity, string(_newUri),content.expiration,expirationTime[identity],payType);
    }

    function burnSubDomain(uint256 tokenId,string calldata label) external override{
        uint256 _subTokenId = makeIdentity(tokenId, label);
        require(isApprovedOrOwner(msg.sender,_subTokenId),"No permission to burn");
        _burnDomain(tokenId,label);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override{
        require(timeHelper(tokenId) > block.timestamp);
        super._transfer(from,to,tokenId);
    }

    function _burnDomain(uint256 tokenId, string calldata label) internal {
        uint256 _subTokenId = makeIdentity(tokenId, label);
        // remove sub tokenIds itself
        _domainTokenIds[tokenId].remove(_subTokenId);
        totalSupply -= 1;
        if (_domainResolver[tokenId] != address(0)) {
            delete _domainResolver[tokenId];
        }
        super._burn(_subTokenId);
    }

    function transferDomain(address from,address to,string calldata label) external override onlyApprovedOrOwner(makeIdentity(KID_ROOT_HASH, label)){
        _transfer(from, to, makeIdentity(KID_ROOT_HASH, label));
    }

    function safeTransferDomain(address from, address to, string calldata label, bytes calldata data) external override onlyApprovedOrOwner(makeIdentity(KID_ROOT_HASH, label)){
        _safeTransfer(from, to, makeIdentity(KID_ROOT_HASH, label), data);
    }

    function transferSubDomain(address from, address to, string calldata label, string calldata subLabel) external override
        onlyApprovedOrOwner(makeIdentity(makeIdentity(KID_ROOT_HASH, label), subLabel))
    {
        _transfer(from, to, makeIdentity(makeIdentity(KID_ROOT_HASH, label), subLabel));
    }

    function safeTransferSubDomain(
        address from, 
        address to, 
        string calldata label, 
        string calldata subLabel, 
        bytes calldata _data) external override
        onlyApprovedOrOwner(makeIdentity(makeIdentity(KID_ROOT_HASH, label), subLabel))
    {
        _safeTransfer(from, to, makeIdentity(makeIdentity(KID_ROOT_HASH, label), subLabel), _data);
    }

    function renewalDomainForWhitelisted(Domain.Renew calldata renew) external override{
        require(_validateRenew(renew, Domain.getRenewHash(renew)),"Data validation failed");
        require(renew.expiration >= minExpiration,"Minimum lease term: 1 year");
        uint256 tokenId = makeIdentity(KID_ROOT_HASH, renew.label);
        require(expirationTime[tokenId] + GRACE_PERIOD * 86400 >= block.timestamp);
        require(_exists(tokenId),"The domain does not exist");
        expirationTime[tokenId] = expirationTime[tokenId] + renew.expiration * 86400;
        // uint256[] memory set = _domainTokenIds[tokenId].values();
        // for(uint i=0; i<set.length; i++){
        //     expirationTime[set[i]] = expirationTime[tokenId];
        // }
        emit Renew(tokenId, renew.expiration, expirationTime[tokenId],1);
    }

    function _validateRenew(Domain.Renew calldata renew,bytes32 renewHash) public view returns(bool){
        return SignatureChecker.verify(renewHash, permitAddress, renew.v, renew.r, renew.s, DOMAIN_SEPARATOR);
    }

    function renewalDomain(string calldata label,uint256 expiration) external override payable{
        
        require(expiration >= minExpiration,"Minimum lease term: 1 year");
        uint256 tokenId = makeIdentity(KID_ROOT_HASH, label);
        require(expirationTime[tokenId] + GRACE_PERIOD * 86400 >= block.timestamp);
        require(_exists(tokenId),"The domain does not exist");
        uint256 price = IPriceOracle(priceOracle).getPrice(label, expiration);
        require(price > 0 && msg.value >= price,"Price error");
        safeTransferETH(feeRecipient, msg.value);
        expirationTime[tokenId] = expirationTime[tokenId] + expiration * 86400;
        // uint256[] memory set = _domainTokenIds[tokenId].values();
        // for(uint i=0; i<set.length; i++){
        //     expirationTime[set[i]] = expirationTime[tokenId];
        // }
        emit Renew(tokenId, expiration, expirationTime[tokenId],0);
    }

    function resolverOf(uint256 tokenId) external override view returns (address) {
        address _resolver = _domainResolver[tokenId];
        require (_resolver != address(0));
        return _resolver;
    }

    function setResolver(uint256 tokenId,address _resolver) external override onlyApprovedOrOwner(tokenId){
        _domainResolver[tokenId] = _resolver;
        emit UpdateResolver(tokenId, _resolver);
    }

    function subDomainSet(uint256 tokenId) external view returns(string[] memory,uint){
        require(tokenId != KID_ROOT_HASH,"Data overload");
        uint256[] memory set = _domainTokenIds[tokenId].values();
        string[] memory uri = new string[](set.length);
        for(uint i=0; i<set.length; i++){
            uri[i] = tokenChars[set[i]];
        }
        return (uri,set.length);
    }

    function timeHelper(uint256 tokenId) public view returns(uint256 expiration){
        if(_exists(tokenId)){
            uint count = StringUtil.dotCount(tokenChars[tokenId]);
            if(count > 1) expiration = getExpirationTime(tokenChars[tokenId]) + GRACE_PERIOD * 86400;
            else if(tokenId == KID_ROOT_HASH) expiration = block.timestamp + 2592000;
            else expiration = expirationTime[tokenId] + GRACE_PERIOD * 86400;
        }
    }

    function getExpirationTime(string memory name) public view returns(uint256){
        uint offset = getOffset(name);
        if(offset > 0){
            offset = offset + 1;
        }
        bytes32 labelHash = keccak(bytes(name), offset, bytes(name).length - offset - 4);
        uint256 tokenId = uint256(keccak256(abi.encodePacked(KID_ROOT_HASH,labelHash)));
        return expirationTime[tokenId];
    }

    //Returns the index position of the separator
    function getOffset(string memory name) internal pure returns(uint separator){
        bytes memory labelHash = bytes(name);
        uint i = labelHash.length -1;
        while(i > 0){
            i--;
            if(separator > 0 && separator < labelHash.length - 4) break;
            if(labelHash[i] == 0x2e && StringUtil.dotCount(name) > 1)  separator = i;
        }
    }

    function keccak(
        bytes memory self,
        uint256 offset,
        uint256 len
    ) internal pure returns (bytes32 ret) {
        require(offset + len <= self.length);
        assembly {
            ret := keccak256(add(add(self, 32), offset), len)
        }
    }



}
