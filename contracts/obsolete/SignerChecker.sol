// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library SignerChecker{

    using ECDSA for bytes32;

    function recoverSigner(string memory message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        bytes32 messageHash = keccak256(bytes(message));
        address signeraddress = messageHash.toEthSignedMessageHash().recover(sig);

        return signeraddress;
    
    }

    function splitSignature(bytes memory sig)
       private
       pure
       returns (uint8, bytes32, bytes32)
   {
       require(sig.length == 65);
       
       bytes32 r;
       bytes32 s;
       uint8 v;

       assembly {
           // first 32 bytes, after the length prefix
           r := mload(add(sig, 32))
           // second 32 bytes
           s := mload(add(sig, 64))
           // final byte (first byte of the next 32 bytes)
           v := byte(0, mload(add(sig, 96)))
       }

       return (v, r, s);
   }
}