// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AdminManager is AccessControlEnumerableUpgradeable, OwnableUpgradeable {

    bytes32 public constant OTTM_ADMIN_ROLE = keccak256("OTTM_ADMIN_ROLE");

    function __OttmAdminManagerUpgradeable_init() internal onlyInitializing {
        __OttmAdminManagerUpgradeable_init_unchained();
    }

    function __OttmAdminManagerUpgradeable_init_unchained() internal onlyInitializing {
        __Ownable_init_unchained();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OTTM_ADMIN_ROLE, _msgSender());
    }

    modifier onlyContractAdmin(){
        require(isContractAdmin(), "Caller must be contract admin");
        _;
    }

    function isContractAdmin() public view returns (bool){
        return isContractAdmin(_msgSender());
    }

    function isContractAdmin(address account) public view returns (bool){
        return hasRole(OTTM_ADMIN_ROLE, account) || hasRole(DEFAULT_ADMIN_ROLE, account) || owner() == account;
    }

    function transferRole(bytes32 role, address account) public onlyRole(role) {
        require(_msgSender() != account, "Account must not be equal as message sender");
        _grantRole(role, account);
        _revokeRole(role, _msgSender());
    }

    function getRoleMembers(bytes32 role) public view returns (address[] memory) {
        uint arraySize = getRoleMemberCount(role);
        address[] memory roleMembers = new address[](arraySize);
        for (uint i = 0; i < arraySize; i++) {
            roleMembers[i] = getRoleMember(role, i);
        }
        return roleMembers;
    }

}