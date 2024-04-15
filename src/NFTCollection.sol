//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC721A.sol";
import "./Address.sol";
import "./AccessControl.sol";
import "./Strings.sol";
import "./Initializable.sol";
import "./ECDSA.sol";
import "./ERC2981.sol";
import "./Base64.sol";
import "./ERC2771Recipient.sol";
import "./ReentrancyGuard.sol";
import "./IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTCollection is
    ERC721A,
    ERC2981,
    Initializable,
    ERC2771Recipient,AccessControl
    ,
    ReentrancyGuard
{
    using Address for address payable;
    using Strings for uint256;
    bool internal _preventInitialization;

    mapping(bytes32 => bool) public signatureUsed;
    mapping(address => uint256) public nonces;
    
    struct TokenInfo {
        IERC20 payToken;
        uint256 staticCost; // Static cost in token units for minting when not using an oracle.
        bool useOracle; // Indicates whether to use a Chainlink oracle for dynamic pricing.
        address priceFeedAddress; // Address of the Chainlink Price Feed contract.
    }

    TokenInfo[] public AllowedCrypto;
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
        // The number of free token mints reserved for the contract owner
        uint256 reservedSupply;
        /// The maximum number of tokens the user can mint per transaction.
        uint256 tokensPerMint;
        /// Tokens per person
        uint256 tokenPerPerson;
        // Treasury address is the address where minting fees can be withdrawn to.
        // Use `withdrawFees()` to transfer the entire contract balance to the treasury address.
        address payable treasuryAddress;
        address WhitelistSigner;
        bool isSoulBound;
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

    /**
     *
     * Contract initialization *
     *
     */

    constructor() ERC721A("", "") {
        _preventInitialization = false;
    }

    function setForwarder(address _trustedForwarder) public onlyOwner {
        _setTrustedForwarder(_trustedForwarder);
    }

    /// Contract initializer
    function initialize(
        DeploymentConfig memory deploymentConfig,
        RuntimeConfig memory runtimeConfig
    ) external initializer nonReentrant {
        require(!_preventInitialization, "Cannot be initialized");

        _validateDeploymentConfig(deploymentConfig);

        _transferOwnership(deploymentConfig.owner);

        _deploymentConfig = deploymentConfig;
        _runtimeConfig = runtimeConfig;

        _setTrustedForwarder(deploymentConfig.trustedForwarder);
        if (deploymentConfig.reservedSupply > 0) {
            _reserveMint(
                deploymentConfig.reservedSupply,
                deploymentConfig.owner
            );
        }
        _preventInitialization = true;
    }
    function addToken(
    IERC20 _payToken,
    uint256 _staticCost,
    bool _useOracle,
    address _priceFeedAddress
    ) public onlyOwner {
    AllowedCrypto.push(TokenInfo({
        payToken: _payToken,
        staticCost: _staticCost,
        useOracle: _useOracle,
        priceFeedAddress: _priceFeedAddress
    }));
    }

    function updateToken(
        uint256 _pid,
        uint256 _staticCost,
        bool _useOracle,
        address _priceFeedAddress
    ) public onlyOwner {
        require(_pid < AllowedCrypto.length, "Token ID does not exist");
        AllowedCrypto[_pid].staticCost = _staticCost;
        AllowedCrypto[_pid].useOracle = _useOracle;
        AllowedCrypto[_pid].priceFeedAddress = _priceFeedAddress;
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

    /**
     * The following modifications have been made to the ERC721 contract to introduce soul binding functionality:
     *
     * - The `makeSoulBound()` function is added to enable soul binding. Only the contract owner can call this function,
     *   and once enabled, certain operations will be restricted.
     */
    function makeSoulBound() external onlyOwner {
        _deploymentConfig.isSoulBound = true;
    }

    /**
     * The `disableSoulBound()` function is added to disable soul binding. Only the contract owner can call this function,
     * and once disabled, all operations will be allowed without any restrictions.
     */
    function disableSoulBound() external onlyOwner {
        _deploymentConfig.isSoulBound = false;
    }

    /**
     * The `safeTransferFrom()` function is overridden to include a check for soul binding. If soul binding is enabled
     * and the sender is not the owner, the token transfer will be rejected.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public override {
        require(
            _deploymentConfig.isSoulBound == false,
            "Token transfer not allowed, soul binding enabled and sender is not the owner"
        );

        super.transferFrom(_from, _to, _tokenId);
    }

    /**
     * The `getSoulBoundStatus()` function is added to allow anyone to check the current status of soul binding (enabled or disabled).
     */
    function getSoulBoundStatus() external view returns (bool) {
        return _deploymentConfig.isSoulBound;
    }

    function approve(
        address _approved,
        uint256 _tokenId
    ) public virtual override {
        require(
            _deploymentConfig.isSoulBound == false,
            "Token approval not allowed, soul binding enabled"
        );
        super.approve(_approved, _tokenId);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public override {
        require(
            _deploymentConfig.isSoulBound == false,
            "Token transfer not allowed, soul binding enabled and sender is not the owner"
        );

        super.safeTransferFrom(_from, _to, _tokenId, _data);
    }

    function setApprovalForAll(
        address _operator,
        bool _approved
    ) public virtual override {
        require(
            _deploymentConfig.isSoulBound == false,
            "Set approval for all not allowed, soul binding enabled"
        );
        super.setApprovalForAll(_operator, _approved);
    }

    function burn(uint256 _tokenId) external {
        require(
            _deploymentConfig.isSoulBound == true,
            "Token burn not allowed, soul binding not enabled"
        );
        require(
            _msgSender() == ownerOf(_tokenId),
            "You must be the owner of the token to burn it"
        );
        _burn(_tokenId);
    }

    function revoke(uint256 _tokenId) public onlyOwner {
        require(
            _deploymentConfig.isSoulBound == true,
            "Token revoke not allowed, soul binding not enabled"
        );

        _burn(_tokenId);
    }

    //revoke all tokens from an address when soul binding is enabled
    function revoke_by_owner(uint256[] memory tokenId) external onlyOwner {
        for (uint256 i = 0; i < tokenId.length; i++) {
            revoke(tokenId[i]);
        }
    }

    /**
     *
     * User actions *
     *
     */
    function airdropNFTs(
        address[] memory _wAddress,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < _wAddress.length; i++) {
            _mintTokens(_wAddress[i], _amount);
        }
    }

    /// Mint tokens
    function mint(
        uint256 amount
    )
        external
        payable
        paymentProvided(amount * _runtimeConfig.publicMintPrice)
        nonReentrant
    {
        require(mintingActive(), "Minting has not started yet");

        _mintTokens(_msgSender(), amount);
        _deploymentConfig.treasuryAddress.sendValue(_msgValue());
    }

    function calculateMintCost(uint256 _pid, uint256 _mintAmount) public view returns (uint256 totalCost) {
        TokenInfo memory token = AllowedCrypto[_pid];
        if (token.useOracle) {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(token.priceFeedAddress);
            (, int256 latestPrice, , , ) = priceFeed.latestRoundData();
            require(latestPrice > 0, "Invalid price data");
            uint256 decimals = priceFeed.decimals();
            uint256 usdCostInToken = (token.staticCost * 10**decimals) / uint256(latestPrice);
            totalCost = usdCostInToken * _mintAmount;
        } else {
            totalCost = token.staticCost * _mintAmount;
        }
    }

    function mintWithERC20(uint256 _mintAmount, uint256 _pid) external {
        require(mintingActive(), "Minting is not active");
        require(_mintAmount > 0, "Mint amount cannot be zero");
        require(_mintAmount <= tokensPerMint(), "Exceeds per-transaction limit");
        require(totalSupply() + _mintAmount <= maxSupply(), "Exceeds max supply");

        uint256 totalCost = calculateMintCost(_pid, _mintAmount);
        TokenInfo memory token = AllowedCrypto[_pid];

        // Transferring the ERC20 tokens from the user to the contract treasury
        require(
            token.payToken.transferFrom(_msgSender(), _deploymentConfig.treasuryAddress, totalCost),
            "Payment transfer failed"
        );

        // Proceeding with the minting process
        _mintTokens(_msgSender(), _mintAmount);
    }

    /// Mint tokens if the wallet has been whitelisted
    function presaleMint(
        uint256 amount,
        bytes memory signature,
        uint256 deadline
    )
        external
        payable
        paymentProvided(amount * _runtimeConfig.presaleMintPrice)
        nonReentrant
    {
        require(deadline >= block.timestamp, "SIG_EXPIRED");
        require(presaleActive(), "Presale has not started yet");

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                _msgSender(),
                amount,
                address(this),
                nonces[_msgSender()]++,
                block.chainid,
                deadline
            )
        );
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        address signer = ECDSA.recover(ethSignedMessageHash, signature);

        // //Verify signature
        require(
            signer == _deploymentConfig.WhitelistSigner,
            "Address is not allowlisted"
        );

        require(!_presaleMinted[_msgSender()], "Already minted");
        _presaleMinted[_msgSender()] = true;
        _mintTokens(_msgSender(), amount);
        _deploymentConfig.treasuryAddress.sendValue(_msgValue());
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

    /// Get the number of tokens still available for minting
    function availableSupply() public view returns (uint256) {
        return _deploymentConfig.maxSupply - totalSupply();
    }

    /// Contract owner address
    /// @dev Required for easy integration with OpenSea

    function owner() public view returns (address) {
        return _deploymentConfig.owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
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

    /**
     *
     * Admin actions *
     *
     */

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

    /// Withdraw minting fees to the treasury address
    /// @dev Callable by admin roles only

    /**
     *
     * Internals *
     *
     */

    /// Contract configuration
    RuntimeConfig internal _runtimeConfig;
    DeploymentConfig internal _deploymentConfig;

    /// Mapping for tracking presale mint status
    mapping(address => bool) internal _presaleMinted;

    /// @dev Internal function for performing token mints
    function _mintTokens(address to, uint256 amount) internal {
        require(amount <= _deploymentConfig.tokensPerMint, "Amount too large");
        require(amount <= availableSupply(), "Not enough tokens left");

        _safeMint(to, amount);
    }

    function _reserveMint(uint256 amount, address to) internal {
        require(amount <= availableSupply(), "Not enough tokens left");
        _safeMint(to, amount);
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
        require(
            config.reservedSupply <= config.maxSupply,
            "Reserve greater than supply"
        );
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

    // Checks if metadata has already been revealed and changes baseURI if it wasn't
    function reveal(string memory _baseURI) public onlyRole(ADMIN_ROLE) {
        require(
            bytes(_runtimeConfig.baseURI).length == 0,
            "Metadata already revealed"
        );
        _runtimeConfig.baseURI = _baseURI;
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
    ) public view override(ERC721A, AccessControl, ERC2981) returns (bool) {
        return
            ERC721A.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /// Get the token metadata URI
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

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
    function name() public view override returns (string memory) {
        return _deploymentConfig.name;
    }

    /// @dev Need symbol() to support setting it in the initializer instead of constructor
    function symbol() public view override returns (string memory) {
        return _deploymentConfig.symbol;
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

    /// Check if enough payment was provided
    modifier paymentProvided(uint256 payment) {
        require(_msgValue() >= payment, "Payment too small");
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

    function reservedSupply() public view returns (uint256) {
        return _deploymentConfig.reservedSupply;
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

    function prerevealTokenURI() public view returns (string memory) {
        return _runtimeConfig.prerevealTokenURI;
    }
}
