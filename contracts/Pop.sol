pragma solidity ^0.8.19;

import "./AdminManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pop is
    AdminManager,
    ERC1155PausableUpgradeable,
    ERC1155SupplyUpgradeable,
    UUPSUpgradeable {


    event BadgeMinted(
        uint indexed badgeId,
        address indexed to,
        address indexed minter
    );
    event BadgeBurned(
        uint indexed badgeId,
        address indexed from,
        address indexed burner
    );

    event AdminActionPerformed(
        address indexed admin,
        string reason
    );

    uint public mintCount;
    uint public burnCount;
    string public contractURI;
    uint256[47] __gap;

    function initialize(string memory baseURI, string memory _contractURI, address[] memory admins) public virtual initializer {
        __OttmPopUpgradeable_init(baseURI, _contractURI, admins);
    }

    function __OttmPopUpgradeable_init(string memory baseURI, string memory _contractURI, address[] memory admins) internal onlyInitializing {
        __OttmPopUpgradeable_init_unchained(baseURI, _contractURI, admins);
    }

    function __OttmPopUpgradeable_init_unchained(string memory baseURI, string memory _contractURI, address[] memory admins) internal onlyInitializing {
        contractURI = _contractURI;
        for (uint i = 0; i < admins.length; i++) {
            _grantRole(OTTM_ADMIN_ROLE, admins[i]);
        }
        __Pausable_init_unchained();
        __OttmAdminManagerUpgradeable_init_unchained();
        __ERC1155_init_unchained(baseURI);
    }

    function setContractURI(
        string memory _contractURI
    ) public virtual onlyContractAdmin {
        contractURI = _contractURI;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint[] memory ids,
        uint[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155PausableUpgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint arrayLength = ids.length;
        for (uint i = 0; i < arrayLength; i++) {
            uint badgeId = ids[i];
            uint amount = amounts[i];

            if (from == address(0)) {
                mintCount += amount;
            }
            
            if (to == address(0)) {
                burnCount += amount;
            }
        }
    }

    function uri(
        uint badgeId
    ) public view virtual override returns (string memory) {
        return string.concat(getBaseURI(), StringsUpgradeable.toString(badgeId));
    }

    function setBaseURI(string memory baseURI) public virtual onlyContractAdmin {
        _setURI(baseURI);
    }

    function getBaseURI() public view virtual returns (string memory) {
        return super.uri(0);
    }

    function totalSupply() public view virtual returns (uint) {
        return mintCount - burnCount;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint id,
        uint amount,
        bytes memory data
    ) public virtual override onlyContractAdmin {
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint[] memory ids,
        uint[] memory amounts,
        bytes memory data
    ) public virtual override onlyContractAdmin {
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function withdraw(
        address tokenAddress,
        uint tokenAmount
    ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenAddress == address(0)) {
            address payable withdrawalAddress = payable(msg.sender);
            (bool sent, ) = withdrawalAddress.call{value: tokenAmount}("");
            require(sent, "Failed to send IMX");
        } else {
            IERC20 erc20Contract = IERC20(tokenAddress);
            erc20Contract.transfer(_msgSender(), tokenAmount);
        }
    }

    function claimBadge(
        bytes calldata approvalSignature,
        uint badgeId,
        address paymentTokenAddress,
        uint paymentTokenAmount,
        uint approvalSignatureCreationTime
    ) external payable {
        bytes32 hashedMessage = keccak256(
            abi.encodePacked(
                _msgSender(),
                badgeId,
                paymentTokenAddress,
                paymentTokenAmount,
                approvalSignatureCreationTime
            )
        );
        hashedMessage = ECDSAUpgradeable.toEthSignedMessageHash(hashedMessage);
        address signatureSigner = ECDSAUpgradeable.recover(
            hashedMessage,
            approvalSignature
        );
        require(
            isContractAdmin(signatureSigner),
            "Invalid approval signature signer"
        );

        if (paymentTokenAmount > 0) {
            if (paymentTokenAddress == address(0)) {
                require(
                    msg.value >= paymentTokenAmount,
                    "Insufficient IMX amount received"
                );
            } else {
                IERC20 erc20Contract = IERC20(paymentTokenAddress);
                erc20Contract.transferFrom(
                    _msgSender(),
                    address(this),
                    paymentTokenAmount
                );
            }
        }
        _mint(_msgSender(), badgeId, "0x");
    }

    function mintBadge(
        address to,
        uint badgeId,
        bytes memory data
    ) public virtual onlyContractAdmin {
        _mint(to, badgeId, data);
    }

    function _mint(address to, uint256 id, bytes memory data) internal virtual {
        _mint(to, id, 1, data);
    }

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual override {
        require(
            balanceOf(to, id) == 0 && amount == 1,
            "Accounts can only possess one of each badge"
        );
        super._mint(to, id, amount, data);
    }

    function mintBadgeToManyUsers(
        address[] calldata to,
        uint badgeId,
        bytes calldata data
    ) external onlyContractAdmin {
        for (uint i = 0; i < to.length; i++) {
            _mint(to[i], badgeId, data);
        }
    }

    function mintManyBadgesToManyUsers(
        address[] calldata to,
        uint[] calldata badgeIds,
        bytes calldata data
    ) external onlyContractAdmin {
        for (uint i = 0; i < to.length; i++) {
            _mint(to[i], badgeIds[i], data);
        }
    }

    function safeMintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes memory data
    ) external onlyContractAdmin {
        _mintBatch(to, ids, values, data);
    }

    function mintManyBadgesToUser(
        address to,
        uint[] calldata badgeIds,
        bytes calldata data
    ) external onlyContractAdmin {
        uint arrayLength = badgeIds.length;
        uint[] memory amounts = new uint[](arrayLength);
        for (uint i = 0; i < arrayLength; i++) {
            uint badgeId = badgeIds[i];
            require(
                balanceOf(to, badgeId) == 0,
                "Accounts can only possess one of each badge"
            );
            if (i < arrayLength - 1) {
                for (uint k = i + 1; k < arrayLength; k++) {
                    require(
                        badgeIds[k] != badgeId,
                        "Duplicate badge IDs detected"
                    );
                }
            }
            amounts[i] = 1;
        }
        _mintBatch(to, badgeIds, amounts, data);
    }

    function pause() public virtual onlyContractAdmin {
        _pause();
    }

    function unpause() public virtual onlyContractAdmin {
        _unpause();
    }

    function burnWithAdminAuthority(
        address account,
        uint256 id,
        uint256 value,
        string memory reason
    ) public virtual onlyContractAdmin {
        emit AdminActionPerformed(_msgSender(), reason);
        _burn(account, id, value);
    }

    function burnWithAdminAuthority(
        address account,
        uint256[] memory ids,
        uint256[] memory values,
        string memory reason
    ) public virtual onlyContractAdmin {
        emit AdminActionPerformed(_msgSender(), reason);
        _burnBatch(account, ids, values);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Upgradeable, AccessControlEnumerableUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyContractAdmin {
    }

    receive() external payable {}

    fallback() external payable {}
}
