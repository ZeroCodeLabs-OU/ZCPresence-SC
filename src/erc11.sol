// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1155.sol";
import "./Address.sol";
import "./AccessControl.sol";
import "./Initializable.sol";
import "./ERC2981.sol";
import "./Base64.sol";
import "./ERC1155Supply.sol";
import "./ECDSA.sol";
import "./ERC2771Recipient.sol";
import "./ReentrancyGuard.sol";
import "./IERC20.sol";
import "./IFeeDistribution.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./IMiningPool.sol";
contract MyToken is
    ERC1155,
    ERC2981,
    AccessControl,
    Initializable,
    ERC1155Supply,
    ERC2771Recipient,
    ReentrancyGuard
{
    using Address for address;
    using Strings for uint256;

    bool internal _preventInitialization;

    mapping(bytes32 => bool) public signatureUsed;
    mapping(address => uint256) nonces;
    event TokensDeposited(uint256 amount);
    event TokenPriceUpdated(uint256 newPrice);
    event USDTWithdrawn(uint256 amount);
    struct TokenInfo {
        IERC20 payToken;
        uint256 staticCost;  // Static cost in token units for minting.
        bool useOracle;  // Indicates if Chainlink oracle is used for dynamic pricing.
        address priceFeedAddress;  // Chainlink Price Feed contract address.
    }

    TokenInfo[] public allowedTokens;

    struct DeploymentConfig {
        string name;
        string symbol;
        address owner;
        uint256 maxSupply;
        uint256[] tokenQuantity;
        uint256 tokensPerMint;
        uint256 tokenPerPerson;
        address treasuryAddress;
        bool openedition;
        IERC20 payToken;
        bool useOracle;
        address priceFeedAddress;
        address feeDistributionAddress;
        uint256 feePercentage; // Fee percentage in basis points (100 bps = 1%)
        uint256 minimumMintPrice; // Minimum price for minting
        address miningPool; // Address of the mining pool contract
        uint256 burnPrice; // Price required for burning if the mint price is below the minimum

    }

    struct RuntimeConfig {
        string baseURI;
        bool metadataUpdatable;
        uint256 publicMintPrice;
        bool publicMintPriceFrozen;
        uint256 publicMintStart;
        string prerevealTokenURI;
        uint256 royaltiesBps;
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

    uint256 public constant VERSION = 1_03_00;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint16 public constant ROYALTIES_BASIS = 10000;

    mapping(address => uint256) public userTokensNFTPublicSale;
    uint256[] public mintedTokenId;
    mapping(uint256 => bool) public isTokenExist;

    constructor() ERC1155("") {
        _preventInitialization = false;
    }

    function initialize(
        DeploymentConfig memory deploymentConfig,
        RuntimeConfig memory runtimeConfig,
        ReservedMint memory reservedDetails
    ) public initializer nonReentrant {
        require(!_preventInitialization, "");

        require(
            deploymentConfig.tokenQuantity.length == deploymentConfig.maxSupply,
            ""
        );
        _validateDeploymentConfig(deploymentConfig);

        _transferOwnership(deploymentConfig.owner);

        _deploymentConfig = deploymentConfig;
        _runtimeConfig = runtimeConfig;

        // Add the first token to allowedTokens
        allowedTokens.push(TokenInfo({
            payToken: deploymentConfig.payToken,
            staticCost: runtimeConfig.publicMintPrice,
            useOracle: deploymentConfig.useOracle,
            priceFeedAddress: deploymentConfig.priceFeedAddress
        }));

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
        return ERC2771Recipient._msgSender();
    }

    function _msgData()
        internal
        view
        override(ERC2771Recipient, Context)
        returns (bytes calldata)
    {
        return ERC2771Recipient._msgData();
    }
    function addUSDT(uint256 amount) public onlyOwner {
        require(_deploymentConfig.payToken.transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
        emit TokensDeposited(amount);
    }

    function withdrawUSDT(uint256 amount) public onlyOwner {
        require(_deploymentConfig.payToken.transfer(msg.sender, amount), "Withdrawal failed");
        emit USDTWithdrawn(amount);
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

    function mint(
        uint256 amount,
        uint256 id,
        uint256 tokenIndex,
        bytes memory data
    )
        external
        nonReentrant
    {
        require(mintingActive(), "");
        require(
            userTokensNFTPublicSale[_msgSender()] + amount <=
                _deploymentConfig.tokenPerPerson,
            ""
        );

        TokenInfo memory tokenInfo = allowedTokens[tokenIndex];
        uint256 totalCost = tokenInfo.staticCost * amount;
        uint256 fee = 0;

        if (totalCost >= _deploymentConfig.minimumMintPrice) {
            fee = (totalCost * _deploymentConfig.feePercentage) / 10000;
            uint256 remainingAmount = totalCost - fee;

            require(
                tokenInfo.payToken.transferFrom(_msgSender(), _deploymentConfig.feeDistributionAddress, fee),
                "ERC20 fee transfer failed"
            );

            require(
                tokenInfo.payToken.transferFrom(_msgSender(), _deploymentConfig.treasuryAddress, remainingAmount),
                "ERC20 payment transfer failed"
            );

            IFeeDistribution(_deploymentConfig.feeDistributionAddress).distributeERC20Fees(tokenInfo.payToken, fee);
        } else {
            require(
                tokenInfo.payToken.transferFrom(_msgSender(), _deploymentConfig.treasuryAddress, totalCost),
                "ERC20 payment transfer failed"
            );
        }

        userTokensNFTPublicSale[_msgSender()] += amount;

        if (isTokenExist[id]) {
            if (_deploymentConfig.openedition) {
                _mintTokens(_msgSender(), id, amount, data);
            } else {
                require(
                    totalSupply(id) + amount <=
                        _deploymentConfig.tokenQuantity[id],
                    ""
                );
                _mintTokens(_msgSender(), id, amount, data);
            }
        } else {
            require(mintedTokenId.length < maxSupply(), "");
            mintedTokenId.push(id);
            isTokenExist[id] = true;

            if (!_deploymentConfig.openedition) {
                require(
                    amount <= _deploymentConfig.tokenQuantity[id],
                    ""
                );
            }

            _mintTokens(_msgSender(), id, amount, data);
        }

        IMiningPool(_deploymentConfig.miningPool).recordMintTx();
    }

    
    function availableToken(uint256 id) public view returns (uint256) {
        return _deploymentConfig.tokenQuantity[id] - totalSupply(id);
    }

    
    
    function burn(uint256 id, uint256 amount) public {
        require(balanceOf(_msgSender(), id) >= amount, "");

        uint256 burnValue = getBurnValue(id, amount);
        _burn(_msgSender(), id, amount);

        if (burnValue < _deploymentConfig.minimumMintPrice) {
            require(
                _deploymentConfig.payToken.transferFrom(
                    msg.sender,
                    _deploymentConfig.feeDistributionAddress,
                    _deploymentConfig.burnPrice
                ),
                "USDT transfer failed"
            );
            IFeeDistribution(_deploymentConfig.feeDistributionAddress).distributeERC20Fees(
                _deploymentConfig.payToken,
                _deploymentConfig.burnPrice
            );
            IMiningPool(_deploymentConfig.miningPool).recordRevokeTx();
            }
    }
    function revoke(address from, uint256 id, uint256 amount) public onlyOwner {

        uint256 burnValue = getBurnValue(id, amount);
        _burn(from, id, amount);

        if (burnValue < _deploymentConfig.minimumMintPrice) {
            require(
                _deploymentConfig.payToken.transferFrom(
                    from,
                    _deploymentConfig.feeDistributionAddress,
                    _deploymentConfig.burnPrice
                ),
                "USDT transfer failed"
            );
            IFeeDistribution(_deploymentConfig.feeDistributionAddress).distributeERC20Fees(
                _deploymentConfig.payToken,
                _deploymentConfig.burnPrice
            );
            IMiningPool(_deploymentConfig.miningPool).recordRevokeTx();
        }
    }


    
    

    function getBurnValue(uint256 id, uint256 amount) internal view returns (uint256) {
        TokenInfo memory tokenInfo = allowedTokens[id];
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
        
        return totalCost * amount;
    }

    function mintingActive() public view returns (bool) {
        return block.timestamp > _runtimeConfig.publicMintStart;
    }

    

    function transferOwnership(
        address newOwner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newOwner != _deploymentConfig.owner, "");
        _transferOwnership(newOwner);
    }

    function transferAdminRights(address to) external onlyRole(ADMIN_ROLE) {
        require(!hasRole(ADMIN_ROLE, to), "");
        require(
            _msgSender() != _deploymentConfig.owner,
            ""
        );

        _revokeRole(ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, to);
    }

    modifier onlyOwner() {
        require(
            _deploymentConfig.owner == _msgSender(),
            ""
        );
        _;
    }

    function getInfo() external view returns (ContractInfo memory info) {
        info.version = VERSION;
        info.deploymentConfig = _deploymentConfig;
        info.runtimeConfig = _runtimeConfig;
    }

    function updateConfig(
        RuntimeConfig calldata newConfig
    ) external onlyRole(ADMIN_ROLE) {
        _validateRuntimeConfig(newConfig);
        _runtimeConfig = newConfig;
    }

    RuntimeConfig internal _runtimeConfig;
    DeploymentConfig internal _deploymentConfig;


    function _mintTokens(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(amount <= _deploymentConfig.tokensPerMint, "");
        _mint(to, id, amount, data);
    }

    
    function _reserveMint(
        ReservedMint memory reserveDetails,
        address sender
    ) internal {
        require(
            reserveDetails.amounts.length == reserveDetails.tokenIds.length,
            ""
        );

        for (uint256 i = 0; i < reserveDetails.amounts.length; i++) {
            uint256 id = reserveDetails.tokenIds[i];
            uint256 amount = reserveDetails.amounts[i];
            require(
                totalSupply(id) + amount <= _deploymentConfig.tokenQuantity[id],
                ""
            );
            if (isTokenExist[id]) {
                _mint(sender, id, amount, "");
            } else {
                require(
                    mintedTokenId.length < _deploymentConfig.maxSupply,
                    ""
                );
                mintedTokenId.push(id);
                isTokenExist[id] = true;
                _mint(sender, id, amount, "");
            }
        }
    }

    function _validateDeploymentConfig(
        DeploymentConfig memory config
    ) internal pure {
        require(config.maxSupply > 0, "");
        require(config.tokensPerMint > 0, "");
        require(
            config.treasuryAddress != address(0),
            ""
        );
        require(config.owner != address(0), "");
        require(config.feeDistributionAddress != address(0), "Invalid fee distribution address");
        require(config.feePercentage <= 10000, "Fee percentage must be less than or equal to 100%");
    }

    function _validateRuntimeConfig(
        RuntimeConfig calldata config
    ) internal view {
        require(config.royaltiesBps <= ROYALTIES_BASIS, "");

        _validatePublicMintPrice(config);

        _validateMetadata(config);
    }

    function _validatePublicMintPrice(
        RuntimeConfig calldata config
    ) internal view {
        if (!_runtimeConfig.publicMintPriceFrozen) return;

        require(
            _runtimeConfig.publicMintPrice == config.publicMintPrice,
            ""
        );

        require(
            config.publicMintPriceFrozen,
            ""
        );
    }

    

    function _validateMetadata(RuntimeConfig calldata config) internal view {
        if (_runtimeConfig.metadataUpdatable) return;

        require(!config.metadataUpdatable, "");

        require(
            keccak256(abi.encodePacked(_runtimeConfig.baseURI)) ==
                keccak256(abi.encodePacked(config.baseURI)),
            ""
        );
    }

    function _transferOwnership(address newOwner) internal {
        address previousOwner = _deploymentConfig.owner;
        _revokeRole(ADMIN_ROLE, previousOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, previousOwner);

        _deploymentConfig.owner = newOwner;
        _grantRole(ADMIN_ROLE, newOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl, ERC2981) returns (bool) {
        return
            ERC1155.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        require(isTokenExist[tokenId], "");

        if (bytes(_runtimeConfig.baseURI).length > 0) {
            return
                string(
                    abi.encodePacked(_runtimeConfig.baseURI, tokenId.toString())
                );
        } else {
            return
                string(
                    abi.encodePacked(
                        _runtimeConfig.prerevealTokenURI,
                        tokenId.toString()
                    )
                );
        }
    }

    function name() external view returns (string memory) {
        return _deploymentConfig.name;
    }

    function symbol() external view returns (string memory) {
        return _deploymentConfig.symbol;
    }

    function owner() external view returns (address) {
        return _deploymentConfig.owner;
    }

    function royaltyInfo(
        uint256,
        uint256 salePrice
    ) public view override returns (address receiver, uint256 royaltyAmount) {
        receiver = _runtimeConfig.royaltiesAddress;
        royaltyAmount =
            (_runtimeConfig.royaltiesBps * salePrice) /
            ROYALTIES_BASIS;
    }

    function contractURI() external view returns (string memory) {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"seller_fee_basis_points": ',
                        _runtimeConfig.royaltiesBps.toString(),
                        ', "fee_recipient": "',
                        uint256(uint160(_runtimeConfig.royaltiesAddress))
                            .toHexString(20),
                        '"}'
                    )
                )
            )
        );

        return string(
            abi.encodePacked("data:application/json;base64,", json)
        );
    }

    function reveal(string memory _baseURI) public onlyRole(ADMIN_ROLE) {
        require(
            bytes(_runtimeConfig.baseURI).length == 0,
            ""
        );
        _runtimeConfig.baseURI = _baseURI;
    }

    function maxSupply() internal view returns (uint256) {
        return _deploymentConfig.maxSupply;
    }

    function tokenQuantity() internal view returns (uint256[] memory) {
        return _deploymentConfig.tokenQuantity;
    }

    function publicMintPrice() internal view returns (uint256) {
        return _runtimeConfig.publicMintPrice;
    }

    function tokensPerMint() internal view returns (uint256) {
        return _deploymentConfig.tokensPerMint;
    }

    function tokensPerPerson() internal view returns (uint256) {
        return _deploymentConfig.tokenPerPerson;
    }

    function treasuryAddress() external view returns (address) {
        return _deploymentConfig.treasuryAddress;
    }

    function publicMintStart() external view returns (uint256) {
        return _runtimeConfig.publicMintStart;
    }

    function baseURI() external view returns (string memory) {
        return _runtimeConfig.baseURI;
    }

    function metadataUpdatable() external view returns (bool) {
        return _runtimeConfig.metadataUpdatable;
    }

    function openedition() external view returns (bool) {
        return _deploymentConfig.openedition;
    }

    function prerevealTokenURI() external view returns (string memory) {
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
