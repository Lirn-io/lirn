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

contract SoulboundUUPSv2 is
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

    string public constant CONTRACT_NAME = "SoulboundV2";

    string public constant VERSION = "2";

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    string defaultURI;

    address internal _signerAddress;

    mapping(address => address) approvedForMigration;
    mapping(uint256 => string) tokenToURI;
    mapping(address => mapping(uint256 => bool)) minted;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CustomURISet(uint256 indexed id, string indexed uri);
    event DefaultURISet(string indexed uri);
    event SignerSet(address signer);

    function initialize(address signer, string memory baseURI)
        public
        initializer
    {
        __ERC1155_init(baseURI);
        __Ownable_init();
        __Pausable_init();
        __ERC1155Supply_init();

        _signerAddress = signer; // TESTING ADDRESS
        defaultURI = baseURI;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                                 USER
    //////////////////////////////////////////////////////////////*/

    //@note Do they need a batchClaim function?
    /*
     * @notice Handles claiming of a course NFT with a custom metadata URI
     * @param _signature - a message signed by the _signerAddress, approves minting of a specific token to a specific address
     * @param tokenId - the ID of the token to be minted.
     * @param uri - The custom URI of the token
     * @param expiration - Timestamp at which the signature will expire
     * @dev It is important to check that we're not minting a courseTokenId that already exists
     */
    function claim(
        bytes memory _signature,
        uint256 id,
        string memory customUri,
        uint256 expiration
    ) external payable {
        // ----- Checks -----
        require(!minted[msg.sender][id], "Already claimed");
        require(block.timestamp < expiration, "Signature expired");

        bytes32 msgHash = keccak256(
            abi.encode(address(this), id, customUri, expiration, msg.sender)
        );

        //@note Something to consider for the future is replay protection if project is deployed on other chains at the same address
        require(
            msgHash.toEthSignedMessageHash().recover(_signature) ==
                _signerAddress,
            "INCORRECT_SIGNATURE"
        );

        // ----- Effects -----
        minted[msg.sender][id] = true;

        // If tokenURI is already set for this particular ID, skip setting it
        if (bytes(tokenToURI[id]).length == 0) {
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
                ? string.concat(defaultURI, id.toString())
                : URI;
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice Mints a token ID to an address
     * @param to - Address of receiver
     * @param id - Token ID
     * @param uri - The custom URI of the token
     * @note - Since the admin is minting tokens to the user, should minted[user][id] be set to true or not?
     * @note - Should I check for an empty input string?
     */
    function mint(
        address to,
        uint256 id,
        string memory customUri
    ) external onlyOwner {
        if (bytes(tokenToURI[id]).length == 0) {
            tokenToURI[id] = customUri;
        }
        _mint(to, id, 1, "");
    }

    /*
     * @notice Mints a single token ID to multiple addresses
     * @param to - Array of addresses
     * @param id - Token ID
     * @param uri - The custom URI of the token
     * @note - Since the admin is minting tokens to the user, should minted[user][id] be set to true or not?
     * @note - Should I check for an empty input string?
     */
    function batchMint(
        address[] calldata to,
        uint256 id,
        string memory customUri
    ) external onlyOwner {
        // What if string is empty?
        if (bytes(tokenToURI[id]).length == 0) {
            tokenToURI[id] = customUri;
        }

        for (uint256 i; i < to.length; ) {
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
     * @notice Sets the defaultURI
     * @param uri - The default URI string
     */
    function setSigner(address signer) external onlyOwner {
        _signerAddress = signer;
        emit SignerSet(signer);
    }

    /// @dev Override of the token transfer hook that blocks all transfers BUT the mint.
    ///        This is a precursor to non-transferable tokens.
    ///        We may adopt something like ERC1238 in the future.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        require(
            (from == address(0) && to != address(0)) ||
                (approvedForMigration[from] == to && to != address(0)),
            "Transfer not allowed"
        );
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
