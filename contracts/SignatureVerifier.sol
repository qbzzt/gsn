// SPDX-License-Identifier:MIT
pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./interfaces/ISignatureVerifier.sol";
import "./utils/GsnUtils.sol";

contract SignatureVerifier is ISignatureVerifier{

    using ECDSA for bytes32;

    string public override versionSM = "2.0.0-alpha.1+opengsn.sv.isignatureverifier";

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    bytes32 public constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    // solhint-disable-next-line max-line-length
    bytes32 public constant RELAY_REQUEST_TYPEHASH = keccak256("RelayRequest(address target,bytes encodedFunction,GasData gasData,RelayData relayData)GasData(uint256 gasLimit,uint256 gasPrice,uint256 pctRelayFee,uint256 baseRelayFee)RelayData(address senderAddress,uint256 senderNonce,address relayWorker,address paymaster,address forwarder)");

    // solhint-disable-next-line max-line-length
    bytes32 public constant CALLDATA_TYPEHASH = keccak256("GasData(uint256 gasLimit,uint256 gasPrice,uint256 pctRelayFee,uint256 baseRelayFee)");

    // solhint-disable-next-line max-line-length
    bytes32 public constant RELAYDATA_TYPEHASH = keccak256("RelayData(address senderAddress,uint256 senderNonce,address relayWorker,address paymaster,address forwarder)");

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR; //not constant - based on chainId

    constructor (address verifier) public {
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name : "GSN Relayed Transaction",
            version : "1",
            chainId : GsnUtils.getChainID(),
            verifyingContract : verifier
        }));
    }

    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            ));
    }

    function hash(RelayRequest memory req) internal pure returns (bytes32) {
        return keccak256(abi.encode(
                RELAY_REQUEST_TYPEHASH,
                    req.target,
                    keccak256(req.encodedFunction),
                    hash(req.gasData),
                    hash(req.relayData)
            ));
    }

    function hash(GasData memory req) internal pure returns (bytes32) {
        return keccak256(abi.encode(
                CALLDATA_TYPEHASH,
                req.gasLimit,
                req.gasPrice,
                req.pctRelayFee,
                req.baseRelayFee
            ));
    }

    function hash(RelayData memory req) internal pure returns (bytes32) {
        return keccak256(abi.encode(
                RELAYDATA_TYPEHASH,
                req.senderAddress,
                req.senderNonce,
                req.relayWorker,
                req.paymaster,
                req.forwarder
            ));
    }

    function verify(RelayRequest memory req, bytes memory signature) public view override returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
                "\x19\x01", DOMAIN_SEPARATOR,
                hash(req)
            ));
        return digest.recover(signature) == req.relayData.senderAddress;
    }
}
