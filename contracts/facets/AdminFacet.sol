// SPDX-License-Identifier: Unlicense

pragma solidity 0.8.18;

import "../storage/LibAppStorage.sol";

import {LibDiamond} from "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";

/// @notice Caller of any function in this facet must be the admin address
contract AdminFacet {
    event SetProtocolFeeBasePercentage(uint256 protocolFeeBasePercentage);
    event SetCursedBondPercentage(uint256 cursedBondPercentage);
    event WithdrawProtocolFees(uint256 totalProtocolFees, address withdrawalAddress);
    event SetGracePeriod(uint256 gracePeriod);
    event SetEmbalmerClaimWindow(uint256 embalmerClaimWindow);
    event SetExpirationThreshold(uint256 expirationThreshold);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);

    /// @notice Admin has attempted to set a zero value
    error CannotSetZeroValue();

    /// @notice Caller must be the admin address
    error CallerIsNotAdminOrOwner();

    /// @notice Provided address cannot be zero address
    error ZeroAddress();

    /// @notice Modifier to enforce caller is admin or contract owner
    modifier onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        if (msg.sender != s.admin && msg.sender != LibDiamond.contractOwner()) {
            revert CallerIsNotAdminOrOwner();
        }
        _;
    }

    /// @notice Withdraws the total protocol fee amount from the contract to the specified address
    /// @param withdrawalAddress - the address to withdraw funds to
    function withdrawProtocolFees(address withdrawalAddress) external onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        // Get the total protocol fees from storage
        uint256 totalProtocolFees = s.totalProtocolFees;
        // Set the total protocol fees to 0 before the transfer to avoid reentrancy
        s.totalProtocolFees = 0;
        // Transfer the protocol fee amount to the sender after setting state
        s.sarcoToken.transfer(withdrawalAddress, totalProtocolFees);
        emit WithdrawProtocolFees(totalProtocolFees, withdrawalAddress);
    }

    /// @notice Sets the protocol fee base percentage, used to calculate protocol fees
    /// @notice The denominator is 10000
    /// @param protocolFeeBasePercentage percentage to set
    function setProtocolFeeBasePercentage(uint256 protocolFeeBasePercentage) external onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        s.protocolFeeBasePercentage = protocolFeeBasePercentage;
        emit SetProtocolFeeBasePercentage(protocolFeeBasePercentage);
    }

    /// @notice Sets the digging fee / cursed bond ratio
    /// @notice The denominator is 10000
    /// used to calculate how much bond archaeologists must lock per curse.
    /// @param cursedBondPercentage ratio to set.
    function setCursedBondPercentage(uint256 cursedBondPercentage) external onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        if (cursedBondPercentage == 0) {
            revert CannotSetZeroValue();
        }
        s.cursedBondPercentage = cursedBondPercentage;
        emit SetCursedBondPercentage(cursedBondPercentage);
    }

    /// @notice Updates the resurrection grace period
    /// @notice Denominated in seconds
    /// @param gracePeriod to set
    function setGracePeriod(uint256 gracePeriod) external onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        s.gracePeriod = gracePeriod;
        emit SetGracePeriod(gracePeriod);
    }

    /// @notice Updates the embalmerClaimWindow
    /// @notice Denominated in seconds
    /// @param embalmerClaimWindow to set
    function setEmbalmerClaimWindow(uint256 embalmerClaimWindow) external onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        s.embalmerClaimWindow = embalmerClaimWindow;
        emit SetEmbalmerClaimWindow(embalmerClaimWindow);
    }

    /// @notice Updates the expirationThreshold used during sarcophagus creation
    /// @notice Denominated in seconds
    /// @param expirationThreshold to set
    function setExpirationThreshold(uint256 expirationThreshold) external onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        s.expirationThreshold = expirationThreshold;
        emit SetExpirationThreshold(expirationThreshold);
    }

    /// @notice Transfers admin address to newAdmin.
    /// @param newAdmin to set
    function transferAdmin(address newAdmin) external onlyAdmin {
        AppStorage storage s = LibAppStorage.getAppStorage();
        if (newAdmin == address(0)) {
            revert ZeroAddress();
        }
        s.admin = newAdmin;
        emit AdminTransferred(msg.sender, newAdmin);
    }

    /// @notice Transfers diamond owner to new owner.
    /// @param newOwner to set
    function transferDiamondOwner(address newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(newOwner);
    }

    /// @notice Returns current owner of Diamond contract.
    function getDiamondOwner() external view returns (address) {
        return LibDiamond.contractOwner();
    }
}
