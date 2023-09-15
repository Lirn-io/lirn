//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "openzeppelin-upgradeable/contracts/utils/StringsUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import "openzeppelin-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract SoulboundUUPS is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC1155Upgradeable,
    ERC1155SupplyUpgradeable,
    UUPSUpgradeable
{
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant CONTRACT_NAME = "Soulbound";

    string public constant VERSION = "1";

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    string public defaultURI;

    address public _signerAddress; // Set to private in production

    mapping(address => address) public approvedForMigration;
    mapping(uint256 => string) public tokenToURI;
    mapping(address => mapping(uint256 => bool)) public minted;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CustomURISet(uint256 indexed id, string indexed uri);
    event DefaultURISet(string indexed uri);
    event SignerSet(address signer);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {
        // @note REMOVE IN PRODUCTION - FORGE TEST
        _transferOwnership(0x0000000000000000000000000000000000000B0b);
    }

    function initialize(
        address owner,
        address signer,
        string memory baseURI
    ) public initializer {
        __ERC1155_init(baseURI);
        __Ownable_init();
        __Pausable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        _signerAddress = signer;
        defaultURI = baseURI;
        _transferOwnership(owner);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                                 USER
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice Handles claiming of a course NFT with a custom metadata URI
     * @param _signature - a message signed by the _signerAddress, approves minting of a specific token to a specific address
     * @param tokenId - the ID of the token to be minted.
     * @param uri - The custom URI of the token
     * @param expiration - Timestamp at which the signature will expire
     * @dev It is important to check that we're not minting a courseTokenId that already exists
     * @note Only works when contract is not paused
     */
    function claim(
        bytes memory _signature,
        uint256 id,
        string memory customUri,
        uint256 expiration,
        uint256 price
    ) external payable whenNotPaused {
        // ----- Checks -----
        require(!minted[msg.sender][id], "Already claimed");
        require(block.timestamp < expiration, "Signature expired");
        require(msg.value >= price, "Price too low");

        bytes32 msgHash = keccak256(
            abi.encode(address(this), id, customUri, expiration, msg.sender)
        );

        require(
            msgHash.toEthSignedMessageHash().recover(_signature) ==
                _signerAddress,
            "INCORRECT_SIGNATURE"
        );

        // ----- Effects -----
        minted[msg.sender][id] = true;

        // If tokenURI is already set for this particular ID, skip setting it
        if (bytes(tokenToURI[id]).length == 0 && bytes(customUri).length != 0) {
            tokenToURI[id] = customUri;
        }

        // ----- Interactions -----
        _mint(msg.sender, id, 1, "");
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice Returns the URI where the off chain metadata is stored
     * @param id - The token ID
     * @dev Tokens can have custom URIs so the function needs to check if a custom URI is set
     */
    function uri(uint256 id) public view override returns (string memory) {
        string memory URI = tokenToURI[id];
        require(exists(id), "Nonexistant token");

        return
            bytes(URI).length == 0
                ? string.concat(defaultURI, id.toString(), ".json")
                : URI;
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice pauses the contract
     */
    function pause() public onlyOwner {
        _pause();
    }

    /*
     * @notice unpauses the contract
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /*
     * @notice Mints a token ID to an address
     * @param to - Address of receiver
     * @param id - Token ID
     * @param uri - The custom URI of the token
     */
    function mint(
        address to,
        uint256 id,
        string memory customUri
    ) external onlyOwner {
        require(!minted[to][id], "Already minted");

        if (bytes(tokenToURI[id]).length == 0 && bytes(customUri).length != 0) {
            tokenToURI[id] = customUri;
        }

        minted[to][id] = true;

        _mint(to, id, 1, "");
    }

    /*
     * @notice Mints a single token ID to multiple addresses
     * @param to - Array of addresses
     * @param id - Token ID
     * @param uri - The custom URI of the token
     */
    function batchMint(
        address[] calldata to,
        uint256 id,
        string memory customUri
    ) external onlyOwner {
        if (bytes(tokenToURI[id]).length == 0 && bytes(customUri).length != 0) {
            tokenToURI[id] = customUri;
        }

        for (uint256 i; i < to.length; ) {
            require(!minted[to[i]][id], "Already minted");
            minted[to[i]][id] = true;

            _mint(to[i], id, 1, "");

            unchecked {
                ++i;
            }
        }
    }

    /*
     * @notice Burn a token ID from a user address
     * @param from - Address from which to burn tokens
     * @param id - Token ID to burn
     * @dev - This gives a lot of power to the administrator, might be advisable to add some limitations
     */
    function burn(address from, uint256 id) external onlyOwner {
        _burn(from, id, 1);
    }

    /*
     * @notice Burn multiple token IDs from a user address
     * @param from - Address from which to burn tokens
     * @param ids - An array of addresses to burn
     * @amounts - An array of amounts to burn. This will always be an array of ones, but it's cheaper to pass it via the frontend
     *            than to add logic to create an array in the contract
     * @dev - This gives a lot of power to the administrator, might be advisable to add some limitations
     */
    function batchBurn(
        address from,
        uint256[] calldata amounts,
        uint256[] calldata ids
    ) external onlyOwner {
        _burnBatch(from, ids, amounts);
    }

    /*
     * @notice Sets the customURI path for the specific token ID
     * @param id - The token ID
     * @param uri - The custom URI
     * @dev - If the uri is set before the tokens are minted, the uri won't change to the one passed into the claim function.
     *        If this is desired, it will need to be done via this function
     */
    function setCustomURI(uint256 id, string memory customUri)
        external
        onlyOwner
    {
        tokenToURI[id] = customUri;
        emit CustomURISet(id, customUri);
    }

    /*
     * @notice Sets the defaultURI
     * @param uri - The default URI string
     */
    function setDefaultURI(string memory defaultUri) external onlyOwner {
        defaultURI = defaultUri;
        emit DefaultURISet(defaultUri);
    }

    /*
     * @notice Sets the signer addresss
     * @param signer - the address of the signer for signed messages ECDSA
     */
    function setSigner(address signer) external onlyOwner {
        _signerAddress = signer;
        emit SignerSet(signer);
    }

    /// @dev Override of the token transfer hook that blocks all transfers BUT the mint.
    ///        This is a precursor to non-transferable tokens.
    ///        We may adopt something like ERC1238 in the future.
    /// @dev Only if not paused
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
        whenNotPaused
    {
        require(
            (from == address(0) && to != address(0)) ||
                (approvedForMigration[from] == to && to != address(0)) ||
                _msgSender() == owner(),
            "Transfer not allowed"
        );
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
