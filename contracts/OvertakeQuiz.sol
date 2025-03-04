// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract OvertakeQuiz is Initializable, OwnableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;

    EnumerableSetUpgradeable.AddressSet private participants;
    EnumerableMapUpgradeable.AddressToUintMap private lastParticipationMap;

    event QuizCompleted(address indexed participant);

    function initialize() public initializer {
        __Ownable_init();
    }

    function participateInQuiz() public {
        uint256 resetTimeUTC1AM = (block.timestamp + 3600) / 1 days * 1 days - 3600;
        (bool hasParticipated, uint256 lastParticipationTime) = lastParticipationMap.tryGet(msg.sender);
        require(!hasParticipated || lastParticipationTime < resetTimeUTC1AM, "You can only participate once per day");

        if (!participants.contains(msg.sender)) {
            participants.add(msg.sender);
        }
        lastParticipationMap.set(msg.sender, block.timestamp);
        emit QuizCompleted(msg.sender);
    }

    function getLastParticipation(address participant) public view returns (uint256) {
        (bool hasParticipated, uint256 lastParticipationTime) = lastParticipationMap.tryGet(participant);
        require(hasParticipated, "No participation record for this user");
        return lastParticipationTime;
    }

    function getParticipantCount() public view returns (uint256) {
        return participants.length();
    }
}
