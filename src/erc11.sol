// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./ERC1155.sol";
import "./Address.sol";
import "./Strings.sol";
import "./AccessControl.sol";
import "./Initializable.sol";
import "./ERC2981.sol";
import "./Base64.sol";
import "./ERC1155Supply.sol";
import "./ECDSA.sol";
import "./ERC2771Recipient.sol";
import "./ReentrancyGuard.sol";

import "./IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
contract MyToken is
    ERC1155,
    ERC2981,
    AccessControl,
    Initializable,
    ERC1155Supply,
    ERC2771Recipient,
    ReentrancyGuard
{
    using Address for address payable;
    using Strings for uint256;
    bool internal _preventInitialization;

    mapping(bytes32 => bool) public signatureUsed;
    mapping(address => uint256) nonces;
    struct TokenInfo {
        IERC20 payToken;
        uint256 staticCost;  // Static cost in token units for minting.
        bool useOracle;  // Indicates if Chainlink oracle is used for dynamic pricing.
        address priceFeedAddress;  // Chainlink Price Feed contract address.
    }

    TokenInfo[] public allowedTokens;

    /// Fixed at deployment time
    struct DeploymentConfig {
        // Name of the NFT contract.
        string name;
        // Symbol of the NFT contract.
        string symbol;
        // The contract owner address. If you wish to own the contract, then set it as your wallet address.
        // This is also the wallet that can manage the contract on NFT marketplaces. Use `transferOwnership()`
        // to update the contract owner.
        address owner;
        // The maximum number of tokens that can be minted in this collection.
        uint256 maxSupply;
        // The maximum number of tokens with specific Id that can be minted, 0 index == tokenId 1
        uint256[] tokenQuantity;
        /// The maximum number of tokens the user can mint per transaction.
        uint256 tokensPerMint;
        /// Tokens per person
        uint256 tokenPerPerson;
        // Treasury address is the address where minting fees can be withdrawn to.
        // Use `withdrawFees()` to transfer the entire contract balance to the treasury address.
        address payable treasuryAddress;
        address WhitelistSigner;
        bool isSoulBound;
        //Open edition means no maxsupply on the token Id edition
        bool openedition;
        address trustedForwarder;
    }

    /// Updatable by admins and owner
    struct RuntimeConfig {
        // Metadata base URI for tokens, NFTs minted in this contract will have metadata URI of `baseURI` + `tokenID`.
        // Set this to reveal token metadata.
        string baseURI;
        // If true, the base URI of the NFTs minted in the specified contract can be updated after minting (token URIs
        // are not frozen on the contract level). This is useful for revealing NFTs after the drop. If false, all the
        // NFTs minted in this contract are frozen by default which means token URIs are non-updatable.
        bool metadataUpdatable;
        // Minting price per token for public minting
        uint256 publicMintPrice;
        // Flag for freezing the public mint price
        bool publicMintPriceFrozen;
        // Minting price per token for presale minting
        uint256 presaleMintPrice;
        // Flag for freezing the presale mint price
        bool presaleMintPriceFrozen;
        // Starting timestamp for public minting.
        uint256 publicMintStart;
        // Starting timestamp for whitelisted/presale minting.
        uint256 presaleMintStart;
        // Pre-reveal token URI for placholder metadata. This will be returned for all token IDs until a `baseURI`
        // has been set.
        string prerevealTokenURI;
        // Root of the Merkle tree of whitelisted addresses. This is used to check if a wallet has been whitelisted
        // for presale minting.
        bytes32 presaleMerkleRoot;
        // Secondary market royalties in basis points (100 bps = 1%)
        uint256 royaltiesBps;
        // Address for royalties
        address royaltiesAddress;
    }

    struct ContractInfo {
        uint256 version;
        DeploymentConfig deploymentConfig;
        RuntimeConfig runtimeConfig;
    }

    struct ReservedMint {
        uint256[] tokenIds;
        uint256[] amounts;
    }

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     *
     * Constants *
     *
     */

    /// Contract version, semver-style uint X_YY_ZZ
    uint256 public constant VERSION = 1_03_00;

    /// Admin role
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Basis for calculating royalties.
    // This has to be 10k for royaltiesBps to be in basis points.
    uint16 public constant ROYALTIES_BASIS = 10000;

    /// @dev Managed by the contract

    mapping(address => uint256) public userTokensNFTPublicSale;

    uint256[] public mintedTokenId;

    mapping(uint256 => bool) public isTokenExist;

    constructor() ERC1155("") {
        _preventInitialization = false;
    }

    /// Contract initializer
    function initialize(
        DeploymentConfig memory deploymentConfig,
        RuntimeConfig memory runtimeConfig,
        ReservedMint memory reservedDetails
    ) public initializer nonReentrant {
        require(!_preventInitialization, "Cannot be initialized");

        require(
            deploymentConfig.tokenQuantity.length == deploymentConfig.maxSupply,
            "Token quantity length must be equal to max supply"
        );
        _validateDeploymentConfig(deploymentConfig);

        _transferOwnership(deploymentConfig.owner);

        _deploymentConfig = deploymentConfig;
        _runtimeConfig = runtimeConfig;
        _setTrustedForwarder(deploymentConfig.trustedForwarder);

        if (reservedDetails.tokenIds.length > 0) {
            _reserveMint(reservedDetails, deploymentConfig.owner);
        }
        _preventInitialization = true;
    }

    function _msgSender()
        internal
        view
        override(ERC2771Recipient, Context)
        returns (address)
    {
        // Use the msgSender() function provided by ERC2771Context.sol
        return ERC2771Recipient._msgSender();
    }

    function _msgData()
        internal
        view
        override(ERC2771Recipient, Context)
        returns (bytes calldata)
    {
        // Use the msgSender() function provided by ERC2771Context.sol
        return ERC2771Recipient._msgData();
    }

    function addToken(
        IERC20 _payToken,
        uint256 _staticCost,
        bool _useOracle,
        address _priceFeedAddress
    ) public onlyOwner {
        allowedTokens.push(TokenInfo({
            payToken: _payToken,
            staticCost: _staticCost,
            useOracle: _useOracle,
            priceFeedAddress: _priceFeedAddress
        }));
    }

    function updateToken(
        uint256 _tokenId,
        uint256 _newCost,
        bool _useOracle,
        address _newPriceFeedAddress
    ) public onlyOwner {
        TokenInfo storage token = allowedTokens[_tokenId];
        token.staticCost = _newCost;
        token.useOracle = _useOracle;
        token.priceFeedAddress = _newPriceFeedAddress;
    }


    /**
     *
     * User actions *
     *
     */

    /// Mint tokens
    function mint(
        uint256 amount,
        uint256 id,
        bytes memory data
    )
        external
        payable
        paymentProvided(amount * _runtimeConfig.publicMintPrice)
        nonReentrant
    {
        require(mintingActive(), "Minting has not started yet");
        require(
            userTokensNFTPublicSale[_msgSender()] + amount <=
                _deploymentConfig.tokenPerPerson,
            "You can't buy more tokens"
        );
        userTokensNFTPublicSale[_msgSender()] += amount;

        if (isTokenExist[id] == true) {
            if (_deploymentConfig.openedition == true) {
                // For open edition, mint without checking the tokenQuantity limit
                _mintTokens(_msgSender(), id, amount, data);
            } else {
                // For non-open edition, check the tokenQuantity limit
                require(
                    totalSupply(id) + amount <=
                        _deploymentConfig.tokenQuantity[id],
                    "Token Id limit Exceeds"
                );
                _mintTokens(_msgSender(), id, amount, data);
            }
        } else {
            require(mintedTokenId.length < maxSupply(), "Max limit exceeds");
            mintedTokenId.push(id);
            isTokenExist[id] = true;

            // Additional check when openedition is false
            if (!_deploymentConfig.openedition) {
                require(
                    amount <= _deploymentConfig.tokenQuantity[id],
                    "Token quantity exceeds limit for new token"
                );
            }

            _mintTokens(_msgSender(), id, amount, data);
        }
        _deploymentConfig.treasuryAddress.sendValue(msg.value);
    }
    function mintWithERC20(uint256 _tokenId, uint256 _amount, uint256 _pid, bytes memory data) public payable {
        TokenInfo memory tokenInfo = allowedTokens[_pid];
        uint256 totalCost;

        if (tokenInfo.useOracle) {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(tokenInfo.priceFeedAddress);
            (, int256 latestPrice, , , ) = priceFeed.latestRoundData();
            require(latestPrice > 0, "Invalid price data");
            uint256 decimals = priceFeed.decimals();
            totalCost = (tokenInfo.staticCost * 10 ** decimals) / uint256(latestPrice);
        } else {
            totalCost = tokenInfo.staticCost;
        }

        totalCost *= _amount;  // Total cost based on the number of tokens to mint.

        require(tokenInfo.payToken.transferFrom(msg.sender, address(this), totalCost), "Payment failed");

        _mint(msg.sender, _tokenId, _amount, data);
    }

    /// Mint tokens if the wallet has been whitelisted

    function presaleMint(
        uint256 amount,
        bytes memory signature,
        uint256 id,
        uint256 deadline
    )
        external
        payable
        paymentProvided(amount * _runtimeConfig.presaleMintPrice)
        nonReentrant
    {
        require(presaleActive(), "Presale has not started yet");

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                _msgSender(),
                id,
                amount,
                address(this),
                nonces[_msgSender()]++,
                block.chainid,
                deadline
            )
        );

        require(deadline >= block.timestamp, "Signature is expired");
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        address signer = ECDSA.recover(ethSignedMessageHash, signature);

        require(
            signer == _deploymentConfig.WhitelistSigner,
            "Address is not allowlisted"
        );
        require(
            _presaleMinted[_msgSender()] == false,
            "Address already minted"
        );
        require(
            !signatureUsed[messageHash],
            "Signature has already been used."
        );

        // Mark the signature as used to prevent reuse
        signatureUsed[messageHash] = true;
        _presaleMinted[_msgSender()] = true;

        require(
            totalSupply(id) + amount <= _deploymentConfig.tokenQuantity[id],
            "Token Id limit Exceeds"
        );

        if (isTokenExist[id] == true) {
            _mintTokens(_msgSender(), id, amount, "");
        } else {
            require(mintedTokenId.length < maxSupply(), "Max limit exceeds");
            mintedTokenId.push(id);
            isTokenExist[id] = true;
            _mintTokens(_msgSender(), id, amount, "");
        }
        _deploymentConfig.treasuryAddress.sendValue(msg.value);
    }

    function availableToken(uint256 id) public view returns (uint256) {
        return _deploymentConfig.tokenQuantity[id] - totalSupply(id);
    }

    /**
     * The following modifications have been made to the ERC1155 contract to introduce soul binding functionality:
     *
     * - The `makeSoulBound()` function is added to enable soul binding. Only the contract owner can call this function,
     *   and once enabled, certain operations will be restricted.
     */
    function makeSoulBound() public onlyOwner {
        _deploymentConfig.isSoulBound = true;
    }

    /**
     * The `disableSoulBound()` function is added to disable soul binding. Only the contract owner can call this function,
     * and once disabled, all operations will be allowed without any restrictions.
     */
    function disableSoulBound() public onlyOwner {
        _deploymentConfig.isSoulBound = false;
    }

    /**
     * The `getSoulBoundStatus()` function is added to allow anyone to check the current status of soul binding (enabled or disabled).
     */

    function getSoulBoundStatus() public view returns (bool) {
        return _deploymentConfig.isSoulBound;
    }

    /**
     * The `safeTransferFrom()` function is overridden to include a check for soul binding. If soul binding is enabled
     * and the sender is not the owner, the token transfer will be rejected.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            _deploymentConfig.isSoulBound == false,
            "Token transfer not allowed, soul binding enabled and sender is not the owner"
        );

        super.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * The `_safeBatchTransferFrom()` internal function is overridden to include a similar check for soul binding when
     * performing batch transfers.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        require(
            _deploymentConfig.isSoulBound == false,
            "Token transfer not allowed, soul binding enabled and sender is not the owner"
        );

        super._safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * The `setApprovalForAll()` function is overridden to include a check for soul binding. If soul binding is enabled,
     * setting approval for all will not be allowed.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        require(
            _deploymentConfig.isSoulBound == false,
            "Set approval for all not allowed, soul binding enabled"
        );
        super.setApprovalForAll(operator, approved);
    }

    /**
     * The `burn()` function is added to allow token burning, but it includes a check for soul binding. If soul binding is
     * not enabled or the caller is not the owner of the token, the burn operation will be rejected.
     */
    function burn(uint256 id, uint256 amount) public {
        require(
            _deploymentConfig.isSoulBound == true,
            "Token burn not allowed, soul binding not enabled"
        );
        require(
            balanceOf(_msgSender(), id) >= amount,
            "You must have enough tokens to burn"
        );
        _burn(_msgSender(), id, amount);
    }

    /**
     * The `revoke()` function is added to allow the contract owner to revoke tokens from a specific address. It includes
     * checks for soul binding and ownership. Only the contract owner can revoke tokens, and soul binding must be enabled.
     */
    function revoke(address from, uint256 id, uint256 amount) public onlyOwner {
        require(
            _deploymentConfig.isSoulBound == true,
            "Token revoke not allowed, soul binding not enabled"
        );

        _burn(from, id, amount);
    }

    /**
     * function is added to allow the contract owner to revoke multiple tokens from multiple
     * addresses at once. It includes checks for array length consistency and calls the `revoke()` function for each address, token, and amount.
     *
     */
    function revoke_by_owner(
        address[] memory _wAddress,
        uint256[] memory _tokenId,
        uint256[] memory _amount
    ) public onlyOwner {
        require(
            _wAddress.length == _tokenId.length &&
                _wAddress.length == _amount.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < _wAddress.length; i++) {
            revoke(_wAddress[i], _tokenId[i], _amount[i]);
        }
    }

    /**
     *
     * View functions *
     *
     */

    /// Check if public minting is active
    function mintingActive() public view returns (bool) {
        // We need to rely on block.timestamp since it's
        // asier to configure across different chains
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp > _runtimeConfig.publicMintStart;
    }

    /// Check if presale minting is active
    function presaleActive() public view returns (bool) {
        // We need to rely on block.timestamp since it's
        // easier to configure across different chains
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp > _runtimeConfig.presaleMintStart;
    }

    /**
     *
     * Access controls *
     *
     */

    /// Transfer contract ownership
    function transferOwnership(
        address newOwner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newOwner != _deploymentConfig.owner, "Already the owner");
        _transferOwnership(newOwner);
    }

    /// Transfer contract ownership
    function transferAdminRights(address to) external onlyRole(ADMIN_ROLE) {
        require(!hasRole(ADMIN_ROLE, to), "Already an admin");
        require(
            _msgSender() != _deploymentConfig.owner,
            "Use transferOwnership"
        );

        _revokeRole(ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, to);
    }

    modifier onlyOwner() {
        require(
            _deploymentConfig.owner == _msgSender(),
            "Ownable: caller is not the owner"
        );
        _;
    }

    /**
     *
     * Admin actions *
     *
     */

    /// Get full contract information
    /// @dev Convenience helper
    function getInfo() external view returns (ContractInfo memory info) {
        info.version = VERSION;
        info.deploymentConfig = _deploymentConfig;
        info.runtimeConfig = _runtimeConfig;
    }

    /// Update contract configuration
    /// @dev Callable by admin roles only
    function updateConfig(
        RuntimeConfig calldata newConfig
    ) external onlyRole(ADMIN_ROLE) {
        _validateRuntimeConfig(newConfig);
        _runtimeConfig = newConfig;
    }

    /// Contract configuration
    RuntimeConfig internal _runtimeConfig;
    DeploymentConfig internal _deploymentConfig;

    /// Mapping for tracking presale mint status
    mapping(address => bool) internal _presaleMinted;

    /// @dev Internal function for performing token mints
    function _mintTokens(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(amount <= _deploymentConfig.tokensPerMint, "Amount too large");
        _mint(to, id, amount, data);
    }

    function airdropNFTs(
        address[] memory _wAddress,
        uint256 id,
        uint256 amount
    ) public virtual onlyRole(ADMIN_ROLE) nonReentrant {
        for (uint256 i = 0; i < _wAddress.length; i++) {
            require(
                totalSupply(id) + amount <= _deploymentConfig.tokenQuantity[id],
                "Token Id limit Exceeds"
            );

            if (isTokenExist[id] == true) {
                _mintTokens(_wAddress[i], id, amount, "");
            } else {
                require(
                    mintedTokenId.length < maxSupply(),
                    "Max limit exceeds"
                );
                mintedTokenId.push(id);
                isTokenExist[id] = true;
                _mintTokens(_wAddress[i], id, amount, "");
            }
        }
    }

    function viewMintedTokenLength() public view returns (uint256) {
        return mintedTokenId.length;
    }

    function _reserveMint(
        ReservedMint memory reserveDetails,
        address sender
    ) internal {
        require(
            reserveDetails.amounts.length == reserveDetails.tokenIds.length,
            "Reserve details array length must be equal"
        );

        for (uint256 i = 0; i < reserveDetails.amounts.length; i++) {
            uint256 id = reserveDetails.tokenIds[i];
            uint256 amount = reserveDetails.amounts[i];
            require(
                totalSupply(id) + amount <= _deploymentConfig.tokenQuantity[id],
                "Token Id limit Exceeds"
            );
            if (isTokenExist[id] == true) {
                _mint(sender, id, amount, "");
            } else {
                require(
                    mintedTokenId.length < _deploymentConfig.maxSupply,
                    "Max limit exceeds"
                );
                mintedTokenId.push(id);
                isTokenExist[id] = true;
                _mint(sender, id, amount, "");
            }
        }
    }

    /// Validate deployment config
    function _validateDeploymentConfig(
        DeploymentConfig memory config
    ) internal pure {
        require(config.maxSupply > 0, "Maximum supply must be non-zero");
        require(config.tokensPerMint > 0, "Tokens per mint must be non-zero");
        require(
            config.treasuryAddress != address(0),
            "Treasury address cannot be null"
        );
        require(config.owner != address(0), "Contract must have an owner");
    }

    /// Validate a runtime configuration change
    function _validateRuntimeConfig(
        RuntimeConfig calldata config
    ) internal view {
        // Can't set royalties to more than 100%
        require(config.royaltiesBps <= ROYALTIES_BASIS, "Royalties too high");

        // Validate mint price changes
        _validatePublicMintPrice(config);
        _validatePresaleMintPrice(config);

        // Validate metadata changes
        _validateMetadata(config);
    }

    function _validatePublicMintPrice(
        RuntimeConfig calldata config
    ) internal view {
        // As long as public mint price is not frozen, all changes are valid
        if (!_runtimeConfig.publicMintPriceFrozen) return;

        // Can't change public mint price once frozen
        require(
            _runtimeConfig.publicMintPrice == config.publicMintPrice,
            "publicMintPrice is frozen"
        );

        // Can't unfreeze public mint price
        require(
            config.publicMintPriceFrozen,
            "publicMintPriceFrozen is frozen"
        );
    }

    function _validatePresaleMintPrice(
        RuntimeConfig calldata config
    ) internal view {
        // As long as presale mint price is not frozen, all changes are valid
        if (!_runtimeConfig.presaleMintPriceFrozen) return;

        // Can't change presale mint price once frozen
        require(
            _runtimeConfig.presaleMintPrice == config.presaleMintPrice,
            "presaleMintPrice is frozen"
        );

        // Can't unfreeze presale mint price
        require(
            config.presaleMintPriceFrozen,
            "presaleMintPriceFrozen is frozen"
        );
    }

    function _validateMetadata(RuntimeConfig calldata config) internal view {
        // If metadata is updatable, we don't have any other limitations
        if (_runtimeConfig.metadataUpdatable) return;

        // If it isn't, we can't allow the flag to change anymore
        require(!config.metadataUpdatable, "Cannot unfreeze metadata");

        // We also can't allow base URI to change
        require(
            keccak256(abi.encodePacked(_runtimeConfig.baseURI)) ==
                keccak256(abi.encodePacked(config.baseURI)),
            "Metadata is frozen"
        );
    }

    /// Internal function without any checks for performing the ownership transfer
    function _transferOwnership(address newOwner) internal {
        address previousOwner = _deploymentConfig.owner;
        _revokeRole(ADMIN_ROLE, previousOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, previousOwner);

        _deploymentConfig.owner = newOwner;
        _grantRole(ADMIN_ROLE, newOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl, ERC2981) returns (bool) {
        return
            ERC1155.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /// Get the token metadata URI
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(isTokenExist[tokenId], "Token does not exist");

        if (bytes(_runtimeConfig.baseURI).length > 0) {
            // Token has been revealed, use the baseURI + tokenId
            return
                string(
                    abi.encodePacked(_runtimeConfig.baseURI, tokenId.toString())
                );
        } else {
            // Token hasn't been revealed, return the pre-reveal token URI
            return
                string(
                    abi.encodePacked(
                        _runtimeConfig.prerevealTokenURI,
                        tokenId.toString()
                    )
                );
        }
    }

    /// @dev Need name() to support setting it in the initializer instead of constructor
    function name() public view returns (string memory) {
        return _deploymentConfig.name;
    }

    /// @dev Need symbol() to support setting it in the initializer instead of constructor
    function symbol() public view returns (string memory) {
        return _deploymentConfig.symbol;
    }

    function owner() public view returns (address) {
        return _deploymentConfig.owner;
    }

    /// @dev ERC2981 token royalty info
    function royaltyInfo(
        uint256,
        uint256 salePrice
    ) public view override returns (address receiver, uint256 royaltyAmount) {
        receiver = _runtimeConfig.royaltiesAddress;
        royaltyAmount =
            (_runtimeConfig.royaltiesBps * salePrice) /
            ROYALTIES_BASIS;
    }

    /// @dev OpenSea contract metadata
    function contractURI() external view returns (string memory) {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"seller_fee_basis_points": ', // solhint-disable-line quotes
                        _runtimeConfig.royaltiesBps.toString(),
                        ', "fee_recipient": "', // solhint-disable-line quotes
                        uint256(uint160(_runtimeConfig.royaltiesAddress))
                            .toHexString(20),
                        '"}' // solhint-disable-line quotes
                    )
                )
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    // Checks if metadata has already been revealed and changes baseURI if it wasn't
    function reveal(string memory _baseURI) public onlyRole(ADMIN_ROLE) {
        require(
            bytes(_runtimeConfig.baseURI).length == 0,
            "Metadata already revealed"
        );
        _runtimeConfig.baseURI = _baseURI;
    }

    /// Check if enough payment was provided
    modifier paymentProvided(uint256 payment) {
        require(msg.value >= payment, "Payment too small");
        _;
    }

    /**
     *
     * Convenience getters *
     *
     */

    function maxSupply() public view returns (uint256) {
        return _deploymentConfig.maxSupply;
    }

    function tokenQuantity() public view returns (uint256[] memory) {
        return _deploymentConfig.tokenQuantity;
    }

    function publicMintPrice() public view returns (uint256) {
        return _runtimeConfig.publicMintPrice;
    }

    function presaleMintPrice() public view returns (uint256) {
        return _runtimeConfig.presaleMintPrice;
    }

    function tokensPerMint() public view returns (uint256) {
        return _deploymentConfig.tokensPerMint;
    }

    function tokensPerPerson() public view returns (uint256) {
        return _deploymentConfig.tokenPerPerson;
    }

    function treasuryAddress() public view returns (address) {
        return _deploymentConfig.treasuryAddress;
    }

    function publicMintStart() public view returns (uint256) {
        return _runtimeConfig.publicMintStart;
    }

    function presaleMintStart() public view returns (uint256) {
        return _runtimeConfig.presaleMintStart;
    }

    function presaleMerkleRoot() public view returns (bytes32) {
        return _runtimeConfig.presaleMerkleRoot;
    }

    function baseURI() public view returns (string memory) {
        return _runtimeConfig.baseURI;
    }

    function metadataUpdatable() public view returns (bool) {
        return _runtimeConfig.metadataUpdatable;
    }

    function openedition() public view returns (bool) {
        return _deploymentConfig.openedition;
    }

    function prerevealTokenURI() public view returns (string memory) {
        return _runtimeConfig.prerevealTokenURI;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
