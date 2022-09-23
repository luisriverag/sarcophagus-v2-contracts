// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import {AppStorage} from "../storage/LibAppStorage.sol";
import { LibDiamond } from "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";

contract AdminFacet {
    AppStorage internal s;

    /// @notice Withdraws the total protocol fee amount from the contract.
    /// @dev Can only be called by the owner.
    function withdrawProtocolFees() external {
        LibDiamond.enforceIsContractOwner();
        // Get the total protocol fees from storage
        uint256 totalProtocolFees = s.totalProtocolFees;

        // Set the total protocol fees to 0 before the transfer to avoid reentrancy
        s.totalProtocolFees = 0;

        // Transfer the protocol fee amount to the sender after setting state
        s.sarcoToken.transfer(msg.sender, totalProtocolFees);
    }

    /// @notice Sets the protocol fee, expressed as a percentage (i.e. 1 = 1%).
    /// @dev Can only be called by the owner.
    function setProtocolFee(uint256 protocolFeeBasePercentage) external {
        LibDiamond.enforceIsContractOwner();
        s.protocolFeeBasePercentage = protocolFeeBasePercentage;
    }
}
