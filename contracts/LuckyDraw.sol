// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interface/IAp.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LuckyDraw is Initializable, UUPSUpgradeable, OwnableUpgradeable, EIP712Upgradeable, ReentrancyGuardUpgradeable {
    using ECDSAUpgradeable for bytes32;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;

    uint256 public maxDrawsPerDay;
    uint256 public participationFee;
    IAp public apToken;
    EnumerableSetUpgradeable.Bytes32Set private usedSignatures;
    bytes32 public constant DRAW_TYPEHASH = keccak256("LuckyDraw(address userAddress,uint256 rewardAmount)");
    string private constant SIGNING_DOMAIN = "LuckyDraw";
    string private constant SIGNATURE_VERSION = "1";

    event SetAPToken(address indexed apToken);
    event LuckyDrawClaim(address indexed userAddress, uint256 amount, bytes signature);

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
    }

    function setAPToken(address _apToken) external onlyOwner {
        require(_apToken != address(0), "APToken address cannot be zero");
        apToken = IAp(_apToken);
        emit SetAPToken(_apToken);
    }

    function setMaxDrawsPerDay(uint256 _maxDrawsPerDay) external onlyOwner {
        maxDrawsPerDay = _maxDrawsPerDay;
    }

    function setParticipationFee(uint256 _participationFee) external onlyOwner {
        participationFee = _participationFee;
    }

    function claim(uint256 rewardAmount, bytes calldata signature, bytes32 salt) public {
        bytes32 digest = _hashTypedDataV4(_buildDomainSeparator(salt), keccak256(abi.encode(DRAW_TYPEHASH, msg.sender, rewardAmount)));
        require(verifySign(msg.sender, rewardAmount, signature, salt) == owner(), "Invalid signature");
        require(!usedSignatures.contains(digest), "Signature already used");

        usedSignatures.add(digest);
        emit LuckyDrawClaim(msg.sender, rewardAmount, signature);
    }

    function claimWithAp(uint256 rewardAmount, bytes calldata signature, bytes32 salt) public nonReentrant {
        bytes32 digest = _hashTypedDataV4(_buildDomainSeparator(salt), keccak256(abi.encode(DRAW_TYPEHASH, msg.sender, rewardAmount)));
        require(verifySign(msg.sender, rewardAmount, signature, salt) == owner(), "Invalid signature");
        require(!usedSignatures.contains(digest), "Signature already used");
        usedSignatures.add(digest);

        apToken.mint(msg.sender, rewardAmount);
        emit LuckyDrawClaim(msg.sender, rewardAmount, signature);
    }

    function verifySign(address userAddress, uint256 amount, bytes memory signature, bytes32 salt) public view returns (address) {
        bytes32 structHash = keccak256(abi.encode(DRAW_TYPEHASH, userAddress, amount));
        bytes32 domainSeparator = _buildDomainSeparator(salt);
        bytes32 digest = _hashTypedDataV4(domainSeparator, structHash);
        address signer = ECDSAUpgradeable.recover(digest, signature);
        return signer;
    }

    function _buildDomainSeparator(bytes32 salt) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"),
                keccak256(bytes(SIGNING_DOMAIN)),
                keccak256(bytes(SIGNATURE_VERSION)),
                block.chainid,
                address(this),
                salt
            )
        );
    }

    function _hashTypedDataV4(bytes32 domainSeparator, bytes32 structHash) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
