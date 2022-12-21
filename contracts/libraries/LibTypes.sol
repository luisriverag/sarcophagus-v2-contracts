// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

/**
 * @title Types shared across facets for the Sarcophagus diamond
 */
library LibTypes {
    struct Sarcophagus {
        // never zero - use for existence checks
        uint256 resurrectionTime;
        // todo: run gas cost evaluation on storing isCompromised vs looping through stored archaeologists and checking isAccused
        bool isCompromised;
        bool isCleaned;
        string name;
        uint8 threshold;
        uint256 maximumRewrapInterval;
        string arweaveTxId;
        address embalmerAddress;
        address recipientAddress;
        address[] cursedArchaeologistAddresses;
        mapping(address => CursedArchaeologist) cursedArchaeologists;
    }

    struct CursedArchaeologist {
        // never empty - use for existence checks
        bytes publicKey;
        bytes32 privateKey;
        bool isAccused;
        uint256 diggingFee;
    }

    struct ArchaeologistProfile {
        bool exists; // todo: use peerid.length instead of exists
        string peerId;
        uint256 minimumDiggingFee;
        uint256 maximumRewrapInterval;
        uint256 freeBond;
        uint256 cursedBond;
    }
}
