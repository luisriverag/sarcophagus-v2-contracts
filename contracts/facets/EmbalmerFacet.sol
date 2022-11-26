// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/LibTypes.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibBonds} from "../libraries/LibBonds.sol";
import {LibUtils} from "../libraries/LibUtils.sol";
import {AppStorage} from "../storage/LibAppStorage.sol";

contract EmbalmerFacet {
    // IMPORTANT: AppStorage must be the first state variable in the facet.
    AppStorage internal s;

    event CreateSarcophagus(
        bytes32 indexed sarcoId,
        string name,
        uint256 resurrectionTime,
        address embalmer,
        address recipient,
        address[] cursedArchaeologists,
        uint256 totalDiggingFees,
        uint256 createSarcophagusProtocolFees,
        string[2] arweaveTxIds
    );

    event RewrapSarcophagus(
        bytes32 indexed sarcoId,
        uint256 resurrectionTime,
        uint256 totalDiggingFees,
        uint256 rewrapSarcophagusProtocolFees
    );

    event BurySarcophagus(bytes32 indexed sarcoId);

    /**
     * Parameters for a sarcophagus, supplied during creation
     * maximumRewrapInterval - highest rewrap interval bonded archaeologists have agreed to accept for lifetime of sarcophagus
     */
    struct SarcophagusParams {
        string name;
        address recipientAddress;
        uint256 resurrectionTime;
        uint256 maximumRewrapInterval;
        uint8 threshold;
        uint256 creationTime;
    }

    /**
     * Parameters for an archaeologist's curse, supplied during sarcophagus creation
     * diggingFee - diggingFee archaeologist has agreed to receive on sarcophagus for its entire lifetime
     */
    struct SelectedArchaeologistData {
        address archAddress;
        uint256 diggingFee;
        bytes32 doubleHashedKeyShare;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice Creates a sarcophagus with the supplied parameters and locks
    /// a portion of each archaeologist's freeBond equal to the diggingFees for the sarcophagus.
    /// Verifies that all supplied archaeologists have signed off on
    ///    - doubleHashedKeyShare assigned to them
    ///    - arweaveTxId for encrypted keyshares
    ///    - maximumRewrapInterval to be enforced for the lifetime of the sarcophagus
    ///    - creationTime of sarcophagus
    ///    - diggingFee to be paid to that archaeologist on all rewraps for the lifetime of the sarcophagus
    ///
    /// @param sarcoId the identifier of the sarcophagus
    /// @param sarcophagusParams params to set on sarcophagus being created
    /// @param selectedArchaeologists the archaeologists the embalmer has selected to curse
    /// @param arweaveTxIds ordered pair of arweave tx ids: [sarcophagus payload tx, encrypted key share tx]
    /// @return The index of the new sarcophagus in sarcophagusIdentifiers
    function createSarcophagus(
        bytes32 sarcoId,
        SarcophagusParams calldata sarcophagusParams,
        SelectedArchaeologistData[] calldata selectedArchaeologists,
        string[2] memory arweaveTxIds
    ) external returns (uint256) {
        // Confirm that sarcophagus with supplied id doesn't already exist
        if (s.sarcophagi[sarcoId].resurrectionTime > 0) {
            revert LibErrors.SarcophagusAlreadyExists(sarcoId);
        }

        // Confirm that agreed upon sarcophagus parameters have not expired
        if (block.timestamp > sarcophagusParams.creationTime + s.expirationThreshold) {
            revert LibErrors.SarcophagusParametersExpired(sarcophagusParams.creationTime);
        }

        // Confirm that resurrection time is in the future
        if (block.timestamp >= sarcophagusParams.resurrectionTime) {
            revert LibErrors.ResurrectionTimeInPast(sarcophagusParams.resurrectionTime);
        }

        // Confirm that resurrection or rewrap will occur before the maximumRewrapInterval elapses
        if (
            block.timestamp + sarcophagusParams.maximumRewrapInterval <
            sarcophagusParams.resurrectionTime
        ) {
            revert LibErrors.ResurrectionTimeTooFarInFuture(
                sarcophagusParams.resurrectionTime,
                sarcophagusParams.maximumRewrapInterval
            );
        }

        // todo: we may not need to validate k and n, is the embalmer hurting anybody by themselves by setting incorrect k/n values?
        // Confirm that archaeologists are provided
        if (selectedArchaeologists.length == 0) {
            revert LibErrors.NoArchaeologistsProvided();
        }
        // Confirm that threshold is greater than 0
        if (sarcophagusParams.threshold == 0) {
            revert LibErrors.MinShardsZero();
        }
        // Confirm that threshold is less than or equal to the number of archaeologists
        // (k <= n in a shamir secret sharing scheme)
        if (sarcophagusParams.threshold > selectedArchaeologists.length) {
            revert LibErrors.MinShardsGreaterThanArchaeologists(sarcophagusParams.threshold);
        }

        // create the sarcophagus
        LibTypes.Sarcophagus storage sarcophagus = s.sarcophagi[sarcoId];
        sarcophagus.name = sarcophagusParams.name;
        sarcophagus.threshold = sarcophagusParams.threshold;
        sarcophagus.resurrectionTime = sarcophagusParams.resurrectionTime;
        sarcophagus.maximumRewrapInterval = sarcophagusParams.maximumRewrapInterval;
        sarcophagus.arweaveTxIds = arweaveTxIds;
        sarcophagus.embalmerAddress = msg.sender;
        sarcophagus.recipientAddress = sarcophagusParams.recipientAddress;
        sarcophagus.cursedArchaeologistAddresses = new address[](selectedArchaeologists.length);

        // track total digging fees due upon creation of sarcophagus
        uint256 totalDiggingFees = 0;

        for (uint256 i = 0; i < selectedArchaeologists.length; i++) {
            // confirm archaeologist is registered
            LibUtils.revertIfArchProfileDoesNotExist(selectedArchaeologists[i].archAddress);

            // Confirm archaeologist isn't already cursed on sarcophagus
            // todo: may be unnecessary, is cursing an archaeologist twice harming anybody but the caller?
            if (
                sarcophagus.cursedArchaeologists[selectedArchaeologists[i].archAddress].doubleHashedKeyShare != 0
            ) {
                revert LibErrors.ArchaeologistListNotUnique(selectedArchaeologists[i].archAddress);
            }

            // Validate the archaeologist has signed off on the sarcophagus parameters
            LibUtils.verifyArchaeologistSignature(
                selectedArchaeologists[i].doubleHashedKeyShare,
                arweaveTxIds[1],
                sarcophagusParams.maximumRewrapInterval,
                sarcophagusParams.creationTime,
                selectedArchaeologists[i].diggingFee,
                selectedArchaeologists[i].v,
                selectedArchaeologists[i].r,
                selectedArchaeologists[i].s,
                selectedArchaeologists[i].archAddress
            );

            totalDiggingFees += selectedArchaeologists[i].diggingFee;

            // Move free bond to cursed bond on archaeologist
            LibBonds.curseArchaeologist(sarcoId, selectedArchaeologists[i].archAddress);

            // save the cursedArchaeologist and cursedArchaeologistAddress to be stored on the new sarcophagus
            sarcophagus.cursedArchaeologists[selectedArchaeologists[i].archAddress] = LibTypes
                .CursedArchaeologist({
                    isAccused: false,
                    diggingFee: selectedArchaeologists[i].diggingFee,
                    doubleHashedKeyShare: selectedArchaeologists[i].doubleHashedKeyShare,
                    rawKeyShare: ""
                });
            sarcophagus.cursedArchaeologistAddresses[i] = selectedArchaeologists[i].archAddress;

            // update archaeologist-specific convenience lookup structures
            s.doubleHashedShardArchaeologists[
                selectedArchaeologists[i].doubleHashedKeyShare
            ] = selectedArchaeologists[i].archAddress;
            s.archaeologistSarcophagi[selectedArchaeologists[i].archAddress].push(sarcoId);
        }

        // update sarcophagus-specific convenience lookup structures
        s.sarcophagusIdentifiers.push(sarcoId);
        s.embalmerSarcophagi[msg.sender].push(sarcoId);
        s.recipientSarcophagi[sarcophagusParams.recipientAddress].push(sarcoId);

        // Transfer totalDiggingFees and the protocolFees in SARCO from embalmer to this contract
        uint256 protocolFees = LibUtils.calculateProtocolFees(totalDiggingFees);
        s.totalProtocolFees += protocolFees;
        s.sarcoToken.transferFrom(msg.sender, address(this), totalDiggingFees + protocolFees);

        emit CreateSarcophagus(
            sarcoId,
            sarcophagusParams.name,
            sarcophagusParams.resurrectionTime,
            msg.sender,
            sarcophagusParams.recipientAddress,
            sarcophagus.cursedArchaeologistAddresses,
            totalDiggingFees,
            protocolFees,
            arweaveTxIds
        );

        // return index of sarcophagus in sarcophagusIdentifiers
        return s.sarcophagusIdentifiers.length - 1;
    }

    /// @notice Updates the resurrectionTime on a sarcophagus. Callable by the embalmer of a sarcophagus if its
    /// resurrection time has not passed, it has not been compromised by >k accusals, and it has not been buried.
    /// @param sarcoId the identifier of the sarcophagus
    /// @param resurrectionTime the new resurrection time
    function rewrapSarcophagus(bytes32 sarcoId, uint256 resurrectionTime) external {
        LibTypes.Sarcophagus storage sarcophagus = s.sarcophagi[sarcoId];

        // Confirm the sarcophagus exists
        if (sarcophagus.resurrectionTime == 0) {
            revert LibErrors.SarcophagusDoesNotExist(sarcoId);
        }

        // Confirm the sarcophagus has not been compromised
        if (sarcophagus.isCompromised) {
            revert LibErrors.SarcophagusCompromised(sarcoId);
        }

        // Confirm the sarcophagus is not buried
        if (sarcophagus.resurrectionTime == 2**256 - 1) {
            revert LibErrors.SarcophagusInactive(sarcoId);
        }

        // Confirm tx sender is embalmer
        if (sarcophagus.embalmerAddress != msg.sender) {
            revert LibErrors.SenderNotEmbalmer(msg.sender, sarcophagus.embalmerAddress);
        }

        // Confirm resurrection time has not yet passed
        if (sarcophagus.resurrectionTime <= block.timestamp) {
            revert LibErrors.SarcophagusIsUnwrappable();
        }

        // Confirm that new resurrection time is in future
        if (resurrectionTime <= block.timestamp) {
            revert LibErrors.NewResurrectionTimeInPast(resurrectionTime);
        }

        // Confirm that new resurrection time doesn't exceed sarcophagus's maximumRewrapInterval
        if (resurrectionTime > block.timestamp + sarcophagus.maximumRewrapInterval) {
            revert LibErrors.NewResurrectionTimeTooLarge(resurrectionTime);
        }

        // track total digging fees across all archaeologists on the sarcophagus
        uint256 totalDiggingFees = 0;

        // pay digging fee to each cursed archaeologist on the sarcophagus
        address[] storage archaeologistAddresses = sarcophagus.cursedArchaeologistAddresses;
        for (uint256 i = 0; i < archaeologistAddresses.length; i++) {
            LibTypes.CursedArchaeologist storage cursedArchaeologist = sarcophagus
                .cursedArchaeologists[archaeologistAddresses[i]];

            // transfer digging fee to archaeologist's reward pool
            // todo: consider adding this amount to archaeologistProfile.freeBond instead
            s.archaeologistRewards[archaeologistAddresses[i]] += cursedArchaeologist.diggingFee;
            totalDiggingFees += cursedArchaeologist.diggingFee;
        }

        uint256 protocolFees = LibUtils.calculateProtocolFees(totalDiggingFees);

        // Add the protocol fee to the total protocol fees in storage
        s.totalProtocolFees += protocolFees;

        // Update the resurrectionTime on the sarcophagus to the supplied value
        sarcophagus.resurrectionTime = resurrectionTime;

        // Transfer the new digging fees and protocol fees from embalmer to contract
        s.sarcoToken.transferFrom(msg.sender, address(this), totalDiggingFees + protocolFees);

        emit RewrapSarcophagus(sarcoId, resurrectionTime, totalDiggingFees, protocolFees);
    }

    /// @notice Terminates a sarcophagus by setting its resurrection time to infinity and returning locked
    /// bonds to all cursed archaeologists. Callable by the embalmer of a sarcophagus if its
    /// resurrection time has not passed, it has not been compromised by >k accusals, and it has not been buried.
    /// @param sarcoId the identifier of the sarcophagus
    function burySarcophagus(bytes32 sarcoId) external {
        LibTypes.Sarcophagus storage sarcophagus = s.sarcophagi[sarcoId];

        // Confirm the sarcophagus exists
        if (sarcophagus.resurrectionTime == 0) {
            revert LibErrors.SarcophagusDoesNotExist(sarcoId);
        }

        // Confirm the sarcophagus has not been compromised
        if (sarcophagus.isCompromised) {
            revert LibErrors.SarcophagusCompromised(sarcoId);
        }

        // Confirm the sarcophagus is not buried
        if (sarcophagus.resurrectionTime == 2**256 - 1) {
            revert LibErrors.SarcophagusInactive(sarcoId);
        }

        // Confirm tx sender is embalmer
        if (sarcophagus.embalmerAddress != msg.sender) {
            revert LibErrors.SenderNotEmbalmer(msg.sender, sarcophagus.embalmerAddress);
        }
        // Confirm that the current resurrection time is in the future
        if (sarcophagus.resurrectionTime <= block.timestamp) {
            revert LibErrors.ResurrectionTimeInPast(sarcophagus.resurrectionTime);
        }

        // Set resurrection time to infinity
        sarcophagus.resurrectionTime = 2**256 - 1;

        // for each archaeologist on the sarcophagus, unlock bond and pay digging fees
        address[] storage archaeologistAddresses = sarcophagus.cursedArchaeologistAddresses;
        for (uint256 i = 0; i < archaeologistAddresses.length; i++) {
            // return locked bond to archaeologist
            LibBonds.freeArchaeologist(sarcoId, archaeologistAddresses[i]);
            // Transfer the digging fees to the archaeologist's reward pool
            // todo: consider adding this amount to archaeologistProfile.freeBond instead
            LibTypes.CursedArchaeologist storage cursedArchaeologist = sarcophagus
                .cursedArchaeologists[archaeologistAddresses[i]];
            s.archaeologistRewards[archaeologistAddresses[i]] += cursedArchaeologist.diggingFee;
        }

        emit BurySarcophagus(sarcoId);
    }
}
