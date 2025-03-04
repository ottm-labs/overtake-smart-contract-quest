// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract Gacha is Initializable, UUPSUpgradeable, OwnableUpgradeable, EIP712Upgradeable, ReentrancyGuardUpgradeable {
    using ECDSAUpgradeable for bytes32;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    EnumerableSetUpgradeable.UintSet private usedClaimPrizeId;
    EnumerableSetUpgradeable.UintSet private usedClaimTicketId;
    bytes32 public constant GACHA_TYPEHASH = keccak256("Gacha(address userAddress,uint256 claimId,address tokenAddress,uint256 rewardAmount)");
    string private constant SIGNING_DOMAIN = "Gacha";
    string private constant SIGNATURE_VERSION = "1";

    event GachaPrizeClaim(address indexed userAddress, uint256 claimPrizeId, bytes signature);
    event GachaTicketClaim(address indexed userAddress, uint256 claimTicketId, bytes signature);
    event SetRewardToken(address indexed tokenAddress);
    event RewardTokenWithdrawn(address indexed tokenAddress, uint256 amount, address indexed to);

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
    }

    function claimTicket(uint256 claimTicketId, bytes calldata signature, bytes32 salt) public {
        bytes32 digest = _hashTypedDataV4(_buildDomainSeparator(salt), keccak256(abi.encode(GACHA_TYPEHASH, msg.sender, claimTicketId, address(this), 0)));
        require(verifySign(msg.sender, claimTicketId, address(this), 0, signature, salt) == owner(), "Invalid signature");
        require(!usedClaimTicketId.contains(claimTicketId), "claimTicketId already used");
        usedClaimTicketId.add(claimTicketId);
        emit GachaTicketClaim(msg.sender, claimTicketId, signature);
    }

    function claimPrize(uint256 claimPrizeId, address tokenAddress, uint256 rewardAmount, bytes calldata signature, bytes32 salt) public {
        bytes32 digest = _hashTypedDataV4(_buildDomainSeparator(salt), keccak256(abi.encode(GACHA_TYPEHASH, msg.sender, claimPrizeId, tokenAddress, rewardAmount)));
        require(verifySign(msg.sender, claimPrizeId, tokenAddress, rewardAmount, signature, salt) == owner(), "Invalid signature");
        require(!usedClaimPrizeId.contains(claimPrizeId), "claimId already used");
        usedClaimPrizeId.add(claimPrizeId);

        if (tokenAddress != address(this) && rewardAmount > 0) {
            IERC20Upgradeable erc20Contract = IERC20Upgradeable(tokenAddress);
            require(erc20Contract.balanceOf(address(this)) >= rewardAmount, "Insufficient token balance in contract");
            erc20Contract.transfer(_msgSender(), rewardAmount);
        }
        emit GachaPrizeClaim(msg.sender, claimPrizeId, signature);
    }

    function verifySign(address userAddress, uint256 claimId, address tokenAddress, uint256 rewardAmount, bytes memory signature, bytes32 salt) public view returns (address) {
        bytes32 structHash = keccak256(abi.encode(GACHA_TYPEHASH, userAddress, claimId, tokenAddress, rewardAmount));
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

    function withdrawTokens(address tokenAddress, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Cannot withdraw to zero address");
        require(IERC20Upgradeable(tokenAddress).balanceOf(address(this)) >= amount, "Insufficient balance");
        IERC20Upgradeable(tokenAddress).transfer(to, amount);
        emit RewardTokenWithdrawn(tokenAddress, amount, to);
    }

    function _hashTypedDataV4(bytes32 domainSeparator, bytes32 structHash) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
