/**
 *Submitted for verification at Etherscan.io on 2021-07-11
*/

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    // function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
    //     require(address(this).balance >= value, "Address: insufficient balance for call");
    //     return _functionCallWithValue(target, data, value, errorMessage);
    // }
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }

  /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.3._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }

    function addressToString(address _address) internal pure returns(string memory) {
        bytes32 _bytes = bytes32(uint256(_address));
        bytes memory HEX = "0123456789abcdef";
        bytes memory _addr = new bytes(42);

        _addr[0] = '0';
        _addr[1] = 'x';

        for(uint256 i = 0; i < 20; i++) {
            _addr[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _addr[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
        }

        return string(_addr);

    }
}

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call. 
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IOwnable {
  function policy() external view returns (address);

  function renounceManagement() external;
  
  function pushManagement( address newOwner_ ) external;
  
  function pullManagement() external;
}

contract Ownable is IOwnable {

    address internal _owner;
    address internal _newOwner;

    event OwnershipPushed(address indexed previousOwner, address indexed newOwner);
    event OwnershipPulled(address indexed previousOwner, address indexed newOwner);

    constructor () {
        _owner = msg.sender;
        emit OwnershipPushed( address(0), _owner );
    }

    function policy() public view override returns (address) {
        return _owner;
    }

    modifier onlyPolicy() {
        require( _owner == msg.sender, "Ownable: caller is not the owner" );
        _;
    }

    function renounceManagement() public virtual override onlyPolicy() {
        emit OwnershipPushed( _owner, address(0) );
        _owner = address(0);
    }

    function pushManagement( address newOwner_ ) public virtual override onlyPolicy() {
        require( newOwner_ != address(0), "Ownable: new owner is the zero address");
        emit OwnershipPushed( _owner, newOwner_ );
        _newOwner = newOwner_;
    }
    
    function pullManagement() public virtual override {
        require( msg.sender == _newOwner, "Ownable: must be new owner to pull");
        emit OwnershipPulled( _owner, _newOwner );
        _owner = _newOwner;
    }
}


interface ITreasury {
    function totalReserves() external view returns(uint);
    function deposit( uint _amount, address _token, uint _profit ) external returns ( uint send_ );
    function manage( address _token, uint _amount ) external;
    function valueOf( address _token, uint _amount ) external view returns ( uint value_ );
}

interface IMiniChefV2 {
    function deposit(uint256 pid, uint256 amount, address to) external;
    function withdraw(uint256 pid, uint256 amount, address to) external;
    function harvest(uint256 pid, address to) external;
    function emergencyWithdraw(uint256 pid, address to) external;
    function pendingSushi(uint256 _pid, address _user) external view returns (uint256 pending);
}

interface IMasset {
    function mint(address _input, uint256 _inputQuantity, uint256 _minOutputQuantity, address _recipient) external virtual returns (uint256 mintOutput);
    function redeem(address _output, uint256 _mAssetQuantity, uint256 _minOutputQuantity, address _recipient) external virtual returns (uint256 outputQuantity);
    function getRedeemOutput(address _output, uint256 _mAssetQuantity) external view virtual returns (uint256 bAssetOutput);
}

interface ICurve {
    function calc_token_amount(uint256[2] memory, bool)  external view returns(uint256);
    function add_liquidity(uint256[2] memory, uint256)  external; // input variables 1. List of amounts of coins to deposit 2. Minimum amount of LP tokens to mint from the deposit
    function remove_liquidity(uint256, uint256[2] memory)  external; // input variables 1. Quantity of LP tokens to burn in the withdrawal 2. Minimum amounts of underlying coins to receive
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function getAmountsOut(uint amountIn, address[2] calldata path) external view returns (uint[] memory amounts);
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
    function removeLiquidity(address tokenA, address tokenB, uint liquidity, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external returns (uint amountToken, uint amountETH);
    function swapExactETHForTokens(uint amountOutMin, address[2] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[2] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function balanceOf(address owner) external view returns (uint);
}

interface IAnyswapV6Router {
    function anySwapOutUnderlying(address token, address to, uint amount, uint toChainID) external;
}

interface ISavingsContractV3 {
    function depositSavings(uint256 _amount, address _beneficiary) external returns (uint256 creditsIssued); // V2
    function balanceOfUnderlying(address _user) external view returns (uint256 underlying); // V2
    function redeemUnderlying(uint256 _amount) external returns (uint256 creditsBurned); // V2
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

/**
 *  Contract deploys reserves from treasury into sushifarm, mStable, curve
 */

contract Allocator is Ownable {

    /* ======== DEPENDENCIES ======== */

    using SafeERC20 for IERC20;
    using SafeMath for uint;



    /* ======== STATE VARIABLES ======== */

    ITreasury immutable treasury; // Olympus Treasury

    IMiniChefV2 immutable sushifarm;
    IMasset immutable mstableMUSD;
    ISavingsContractV3 immutable mstableIMUSD;
    ICurve immutable curve;
    IUniswapV2Router01 immutable sushiSwap;
    IAnyswapV6Router immutable bridge;
    IWETH public immutable WETH;

    address public USDC; // usdc address in arbitrum network
    address public USDCPolygon; // usdc address in polygon network
    address public ldf; // ldf address in arbitrum network
    address public mUSDPolygon; // // mUSD address in polygon network
    address public allcatorArbitrum = 0x0000000000000000000000000000000000000000; // allocator address of arbitrum network
    address public allocatorPolygon = 0x0000000000000000000000000000000000000000; // allocator address of polygon network
    address public ldfUSDCRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // LDF - USDC router contract in arbitrum network

    uint256 public pairBalance;
    // uint256 public totalReserves;

    address[] public aTokens; // all relevant aTokens
    address[] public tokens; // all relevant tokens
    mapping( address => mapping( address => address)) public protocolATokenRegistry; // corresponding aTokens for tokens
    mapping( address => mapping( address => uint )) public poolIDProtocolRegistry; // corresponding poolID 
    mapping( string => uint256) public chainId; 

    uint public totalValueDeployed; // total RFV deployed into lending pool
    mapping( address => uint ) public deployedFor; // amount of token deployed into pool
    mapping( address => uint256 ) public rewardBalance;
    mapping( address => uint ) public deployLimitFor; // max amount can be deployed into protocol
    mapping( address => uint ) public deployLimitOfReserve; // % of reserve that can be deployed into protocol

    uint public immutable timelockInBlocks; // timelock to raise deployment limit
    mapping( address => uint ) public raiseLimitTimelockEnd; // block when new max can be set
    mapping( address => uint ) public newLimit; // pending new deployment limits for protocol
    mapping( address => uint ) public newLimitOfReserve; // pending reserve limit that can be deployed into protocol

    /** Two modes on this contract. Default mode (depositToTreasury = false)
     *  holds aToken in this contract. The alternate mode (depositToTreasury = true)
     *  deposits aToken into the treasury and retrieves it to withdraw. Switching 
     *  to true is contigent on claimOnBehalfOf permission (which must be given
     *  by protocol governance) so that this contract can claim rewards.
     */ 
    bool public depositToTreasury;
    
    /* ======== CONSTRUCTOR ======== */

    constructor ( 
        address _ldf,
        address _treasury,
        address _USDCArbitrum,
        address _USDCPolygon,
        address _mUSDPolygon,
        address _sushifarm, 
        address _mstableMUSD,
        address _mstableIMUSD,
        address _curve,
        address _sushiSwap,
        address _bridge,
        address _WETH,
        uint _timelockInBlocks
    ) {
        require(_ldf != address(0));
        ldf = _ldf;

        require( _treasury != address(0));
        treasury = ITreasury(_treasury);

        require(_USDCArbitrum != address(0));
        USDC = _USDCArbitrum;

        require(_USDCPolygon != address(0));
        USDCPolygon = _USDCPolygon;

        require(_mUSDPolygon != address(0));
        mUSDPolygon = _mUSDPolygon;

        require(_sushifarm != address(0) );
        sushifarm = IMiniChefV2(_sushifarm);

        require(_mstableMUSD != address(0));
        mstableMUSD = IMasset(_mstableMUSD);

        require(_mstableIMUSD != address(0));
        mstableIMUSD = ISavingsContractV3(_mstableIMUSD);

        require(_curve != address(0));
        curve = ICurve(_curve);

        require(_sushiSwap != address(0));
        sushiSwap = IUniswapV2Router01(_sushiSwap); // LDF - USDC router contract address

        require(_bridge != address(0));
        bridge = IAnyswapV6Router(_bridge);

        require(_WETH != address(0));
        WETH = IWETH(_WETH);

        timelockInBlocks = _timelockInBlocks;
    }



    /* ======== OPEN FUNCTIONS ======== */

    /**
     * @notice swap lptoken's to USDC
    */
    function swapLPtoUSDC(address _LPToken, address _Token1, address _Token2, uint _amount) public {
        require(_LPToken != address(0), "LP token address can't be Zero address");
        require(_Token1 != address(0) && _Token2 != address(0), "Token1 or Token2 address can't be Zero address");

        uint256 balanceOfLp = IERC20(_LPToken).balanceOf(address(treasury));

        require(balanceOfLp >= _amount, "Amount is more than the balance of Lp token in treasury");

        treasury.manage(_LPToken, _amount); // withdraw lp token from treasury contract

        address lpTokenRouter = protocolATokenRegistry[_LPToken][_Token2];
        require(lpTokenRouter != address(0), "Enter valid _LPToken or _Token2 address");

        /******* remove liquidity*******/

        if(_Token2 != address(WETH)) {
            IUniswapV2Router01(lpTokenRouter).removeLiquidity( // router address may change from each lp token
                _Token1, // address on token 1
                _Token2, // address on token 2
                _amount, // input amount
                0, // minimum token1 amount to get
                0, // minimum token2 amount to get
                address(this),
                block.timestamp + 1000000 // 30 Mins added to the current time stamp
            ); // remove Liquidity from lp bond 
        } else {
            IUniswapV2Router01(lpTokenRouter).removeLiquidityETH(
                _Token1, // address on token 1
                _amount, // input amount
                0, // minimum token1 amount to get
                0, // minimum token2 amount to get
                address(this), 
                block.timestamp + 1000000 // 30 Mins added to the current time stamp
            ); 
        }
        /******* swap *******/

        if(_Token1 == ldf) {
            uint256 balance = IERC20(_Token1).balanceOf(address(this));
            IERC20(_Token1).approve(address(sushiSwap), balance);
            sushiSwap.swapExactTokensForTokens(
                balance, // amount to be swapped 
                0, // minimum output token
                [_Token1, _Token2], // token path
                address(this), // transfer to this contract
                block.timestamp + 1000000 // 30 Mins added to the current time stamp
            );
        }  // swap LDF to USDC

        uint256 balanceOFETH = address(this).balance; // balance of WETH 
        require(balanceOFETH != 0, "balance of ETH in the contract is <= 0");
        
        if(_Token2 == address(WETH)) { // swap token 2 (id token 2 is ETH)
            IUniswapV2Router01(ldfUSDCRouter).swapExactETHForTokens{value: balanceOFETH}(
                0, // minimum output token
                [_Token1, _Token2], // token path
                address(this), // transfer to this contract
                block.timestamp + 1000000 // 30 Mins added to the current time stamp
            );
        }
    }


    /******** Sushi Farm functions*******/

    /**
    * @notice Useful for calculating optimal token amounts before calling swap.
    */
    function getAmount(uint256 _amount, address _token1, address _token2) public view returns(uint256[] memory){
        return IUniswapV2Router01(sushiSwap).getAmountsOut(
            _amount,
            [_token1, _token2]
        );
    }

    /**
    * @notice convert usdc to lp and deposit them into sushi
    */
    function depositToSushi(address _protocol, address _token, uint256 _amountInUSDC) public {
        require(_amountInUSDC != 0, "Input amount can't be Zero");
        uint balanceOfUSDC = (IERC20(USDC).balanceOf(address(treasury))).add(IERC20(USDC).balanceOf(address(this)));
       
        uint amountToBeDeposit = amountToBeDeployed(address(sushiSwap), _amountInUSDC);
        require(amountToBeDeposit <= balanceOfUSDC, "Insufficient USDC balance");
        require(amountToBeDeposit <= balanceOfUSDC, "Deposit reached their limit"); // check already deposited amount into sushi

        uint USDCAmount = amountToBeDeposit.div(2); // amount to be converted to LDF

        sushiSwap.swapExactTokensForTokens(
            USDCAmount, // USDC amount 
            0, // minimum output token
            [USDC, ldf], // USDC and LDF token addresses
            address(this), // transfer to this contract
            block.timestamp + 1000000 // 30 Mins added to the current time stamp
        ); // swap 50% of USDC to LDF 

        uint ldfAmount = IERC20(ldf).balanceOf(address(this));

        sushiSwap.addLiquidity(
            ldf, // LDF token address
            USDC, // USDC token address 
            ldfAmount, // LDF token amount to be deposited 
            USDCAmount, // USDC token amount to be deposited
            0, // minimum deposit LDF token
            0, // minimum deposit USDC token
            address(this), // transfer to this contract
            block.timestamp + 1000000 // 30 Mins added to the current time stamp
        );

        address factoryAddress = sushiSwap.factory(); // get factory contract of LDF/USDC pool
        address pairAddress = IUniswapV2Factory(factoryAddress).getPair(
            ldf, // LDF token address
            USDC // USDC token address
        ); // get address of the pair 

        uint256 pairBalance = IUniswapV2Pair(pairAddress).balanceOf(address(this)); // get lp token balance for this contract address
        uint256 valueOfLP = treasury.valueOf(pairAddress, pairBalance); // value of lp token 
        uint256 poolId = poolIDProtocolRegistry[_protocol][_token];

        sushifarm.deposit(
            poolId, // pool id of a particular pool 
            pairBalance, // amount of lp token
            address(this)
        );

        accountingFor(pairAddress, valueOfLP, pairBalance, true);
    }

    /**
    * @notice view pending sushi in farm
    */
    function pendingSushi(address _protocol ,address _user, address _token) public view returns(uint256){
        uint256 poolId = poolIDProtocolRegistry[_protocol][_token];
        return IMiniChefV2(sushifarm).pendingSushi(poolId, _user);
    }

    /**
    * @notice deposit aTokens(acknowledgement token) received from protocols into treasury
    * _protocol address
    * _token address
    * _value uint256
    */
    function depositATokenToTreasury(address _protocol, address _token, uint256 _value) public {
        require(_protocol != address(0) && _token != address(0), "Input addresses can't be a zero addresses");
        require(_value != 0, "Input value can't be zero");
        if ( depositToTreasury ) { // if aTokens are being deposited into treasury
            address aToken = protocolATokenRegistry[ _protocol ][ _token ]; // address of aToken
            uint aBalance = IERC20( aToken ).balanceOf( address(this) ); // balance of aToken received

            IERC20( aToken ).approve( address( treasury ), aBalance ); // approve to deposit aToken into treasury
            treasury.deposit( aBalance, aToken, _value ); // deposit using value as profit so no LDF is minted
        }
    }

    /**
    * @notice Withdraw lp token deposited into sushifarm pool and transfer them into treasury
    */
    function withdrawFromSushi(address _protocol, address _token, uint _amount) public onlyPolicy {
        require(_protocol != address(0) && _token != address(0), "Input addresses can't be a zero addresses");
        require(_amount != 0, "Input amount can't be zero");
        address aToken = protocolATokenRegistry[_protocol][_token]; // address of aToken
        uint256 poolId = poolIDProtocolRegistry[_protocol][_token];

        harvestSushi(poolId);// withdraw rewards generated

        IERC20(_token).approve(_protocol, _amount); // approve suhsi token to withdraw form sushifarm
        sushifarm.withdraw(poolId, _amount, address(this)); //withdraw LP token from sushi farm

        uint256 pairBalance = IUniswapV2Pair(aToken).balanceOf(address(this)); // balance of sushi token of this contract

        uint256 value = treasury.valueOf(_token, pairBalance); // value of sushi token

        accountingFor(_token, value, pairBalance, false); // account _token and value 

        IERC20(_token).approve(address(treasury), pairBalance); // approve treasury to spend _token 

        treasury.deposit(pairBalance, _token, value); // deposit sushi tokens to treasury
    } 
    

    /**
    *  @notice claims accrued rewards for all tracked protocols
    */
    function harvestSushi(uint256 _pid) public {
        if(depositToTreasury) {
            sushifarm.harvest(_pid, address(treasury));
        } else {
            sushifarm.harvest(_pid, address(this));
        }
    }

    /******** Curve functions*******/

    /**
    * @notice deposit USDC to curve protocol
    */
    function depositToCurve(uint256 _amountInUSDC) public {
        require(_amountInUSDC != 0, "Input value can't be zero");
        uint256 balanceOfUSDC = (IERC20(USDC).balanceOf(address(treasury))).add(IERC20(USDC).balanceOf(address(this)));
        uint256 amountToBeDeposit = amountToBeDeployed(address(curve), _amountInUSDC);

        require(amountToBeDeposit > 0, "deposit reached their limit"); // ensure deposit is within bounds
        require(amountToBeDeposit <= balanceOfUSDC, "Insufficient USDC");

        curve.add_liquidity(
            [amountToBeDeposit, 0], // List of amounts of coins to deposit
            0 // Minimum amount of LP tokens to mint from the deposit
        );

        address aToken = protocolATokenRegistry[address(curve)][USDC]; // address of aToken
        
        uint balance = IERC20(aToken).balanceOf(address(this));  // amount of LP after adding

        uint value = treasury.valueOf(aToken, balance); // treasury RFV calculator

        accountingFor(aToken, value, balance, true); // account for deposit

        depositATokenToTreasury(address(curve), aToken, value);
    }

    /**
    * @notice withdraw deposited USDC from curve pool and transfer it to treasury
    */
    function withdrawFromCurve( address _token, uint _amount ) public onlyPolicy() {
        require(_token != address(0), "Address can't be zero");
        require(_amount != 0, "Input amount can't be zero");
        address aToken = protocolATokenRegistry[address(curve)][_token]; // aToken to withdraw

        if ( depositToTreasury ) { // if aTokens are being deposited into treasury
            treasury.manage( aToken, _amount ); // retrieve aToken from treasury
        }

        IERC20( aToken ).approve( address( curve ), _amount ); // approve to remove liquidity 

        curve.remove_liquidity(
            _amount, // Quantity of LP tokens to burn in the withdrawal
            [uint256(0), uint256(0)] //  Minimum amounts of underlying coins to receive
        ); // withdraw from Curve pool, returning asset
        
        uint balance = IERC20( _token ).balanceOf( address(this) ); // balance of asset 
        uint value = treasury.valueOf( _token, balance ); // treasury RFV calculator

        accountingFor( _token, value, balance, false ); // account for withdrawal

        IERC20( _token ).approve(address(treasury), balance ); // approve to deposit asset into treasury
        treasury.deposit( balance, _token, value ); // deposit using value as profit so no LDF is minted
    }

    /**
    * @notice set chainID for protocol to bridge token to other chain
    */
    function setChainId(string memory _name, uint256 _Id) public {
        chainId[_name] = _Id;
    }

    /**
    * @notice Bridge USDC from arbitrum to polygon to deposit to mStable
    */
    function bridgeToMStable(string memory _name, uint _amountInUSDC) public {
        require(_amountInUSDC != 0, "Input value can't be zero");
        uint balanceUSDC = (IERC20(address(treasury)).balanceOf( USDC )).add(IERC20( address(this) ).balanceOf( USDC ));

        uint amountToBeDeposit = amountToBeDeployed(address(mstableMUSD), _amountInUSDC );
        require( amountToBeDeposit <= 0, "Deposit reached their limit" ); // ensure deposit is within bounds
        require(amountToBeDeposit <= balanceUSDC, "Insufficient USDC"); 
        
        uint256 toChainID = chainId[_name]; //polygon chain id
        bridge.anySwapOutUnderlying(
            USDC,
            allocatorPolygon,
            amountToBeDeposit,
            toChainID
        );
    }

    /**
    * @notice Deposit USDC to mStable protocol
    */
    function depositToMStable(uint256 _amount) public {
        require(_amount != 0, "Input value can't be zero");
        mstableMUSD.mint(
            USDCPolygon, // Address of the bAsset to deposit for the minted mAsset.
            _amount,// Quantity in bAsset units
            0, // Minimum mAsset quantity to be minted. This protects against slippage.
            address(this) // Recipient of the newly minted mAsset tokens
        ); // mint mUSD by depositing USDC

        address mUSDAddress = protocolATokenRegistry[address(mstableMUSD)][USDCPolygon];

        uint256 balanceOfmUSD = IERC20(mUSDAddress).balanceOf(address(this));

        IERC20(mUSDAddress).approve(address(mstableMUSD), _amount);

        mstableIMUSD.depositSavings(
            balanceOfmUSD, // Units of underlying mUSD to deposit into savings vault
            address(this) // Immediately transfer the imUSD token to this contract
        ); // deposit imUSD into savings contract of mstable

        address imUSDAddress = protocolATokenRegistry[address(mstableIMUSD)][mUSDPolygon];

        uint256 balanceOfimUSD = IERC20(imUSDAddress).balanceOf(address(this)); // balance of imUSD in this contract
        accountingFor(address(mstableIMUSD), _amount, _amount, true); // account for withdrawal
    }

    /**
    * @notice withdraw asset from mStable protocol to get USDC
    */
    function withdrawFromMStable( string memory _name, uint _amount ) public onlyPolicy() {
        require(_amount != 0, "Input value can't be zero");
        address imUSD = protocolATokenRegistry[address(mstableIMUSD)][mUSDPolygon]; // aToken to withdraw

        IERC20( imUSD ).approve( address( mstableIMUSD ), _amount ); // approve to withdraw
        mstableIMUSD.redeemUnderlying(_amount); // withdraw from mStable
        
        uint balance = IERC20(mUSDPolygon).balanceOf( address(this) ); // balance of asset received after withdraw
        mstableMUSD.redeem(
            USDCPolygon, // Address of the bAsset to receive
            balance, // Quantity of mAsset to redeem
            0, // Minimum bAsset quantity to receive
            address(this) // Address to transfer the withdrawn USDC to.
        );

        uint toChainID = chainId[_name]; // chain id of arbitrum network
        bridge.anySwapOutUnderlying(
            USDC, // address of USDC in arbitrum
            allcatorArbitrum, // allocator address in arbitrum network
            balance, // balance of mUSD in polygon network of this contract
            toChainID // chain id of arbitrum network
        );

        accountingFor(address(mstableIMUSD), _amount, _amount, false ); // account for withdrawal
    }

    /**
    * @notice deposit USDC from allocator to treasury
    */
    function depositUSDCToTreasury(address _token) public {
        require(_token != address(0), "Address can't be zero address");
        uint256 balance = IERC20(USDC).balanceOf(address(this));
        uint256 value = treasury.valueOf(_token, balance);

        accountingFor(_token, value, balance, false);

        IERC20(USDC).approve(address(treasury), balance);
        treasury.deposit(balance, _token, value);
    }

    /**
     *  @notice adds asset and corresponding aToken to mapping
     *  @param _protocol address
     *  @param _token address
     *  @param _aToken address
     *  @param _max uint
     *  @param _limit uint
     *  @param _poolID uint
     
     */
    function addToken( address _protocol, address _token, address _aToken, uint _max, uint _limit, uint _poolID ) external onlyPolicy() {
        require( _protocol != address(0), "Protocol address can't be a zero address" );
        require( _token != address(0) && _aToken != address(0), "Token and aToken address can't be a zero addresses" );
        require( protocolATokenRegistry[ _protocol ][ _token ] == address(0) ); // cannot add token twice
        require( _limit <= 10000, "Limit value can't more than 100.00%");

        protocolATokenRegistry[ _protocol ][ _token ] = _aToken; // maps token to aToken
        tokens.push( _token ); // track _token in array 
        aTokens.push( _aToken ); // tracks _aToken in array

        if( _poolID != 0 ) {
            poolIDProtocolRegistry[ _protocol ][ _token ] = _poolID; // maps _poolIDs to its _protocol and _token
        }

        if( _max > 0 ) {
            deployLimitFor[ _protocol ] = _max; // maximum amount to deposit in a protocol 
        }

        if( _limit > 0 ) {
            deployLimitOfReserve[ _protocol ] = _limit; // % of reserve that can be deployed on each deposit
        }
    }

    /**
     *  @notice lowers max can be deployed for asset (no timelock)
     *  @param _protocol address
     *  @param _newMax uint
     *  @param _newLimit uint
     */
    function lowerLimit(address _protocol, uint _newMax, uint _newLimit ) external onlyPolicy() {
        require(_protocol != address(0), "address can't be a zero address");
        require( _newMax < deployLimitFor[ _protocol ] );
        require( _newMax > deployedFor[ _protocol ] ); // cannot set limit below what has been deployed already
        deployLimitFor[ _protocol ] = _newMax;
        deployLimitOfReserve[_protocol] = _newLimit; // % of reserve that can be deployed into protocol 100% = 10000 = 100.00% 
    }
    
    /**
     *  @notice starts timelock to raise max allocation for asset
     *  @param _protocol address
     *  @param _newMax uint
     *  @param _limit uint
     */
    function queueRaiseLimit( address _protocol, uint _newMax, uint _limit ) external onlyPolicy() {
        require(_protocol != address(0), "protocol can't be zero address");
        raiseLimitTimelockEnd[ _protocol ] = block.number.add( timelockInBlocks );
        newLimit[ _protocol ] = _newMax;
        newLimitOfReserve[ _protocol ] = _limit;
    }

    /**
     *  @notice changes max allocation for asset when timelock elapsed
     *  @param _protocol address
     */
    function raiseLimit( address _protocol ) external onlyPolicy() {
        require(_protocol != address(0), "Input value can't be zero");
        require( block.number >= raiseLimitTimelockEnd[ _protocol ], "Timelock not expired" );

        deployLimitFor[ _protocol ] = newLimit[ _protocol ];
        deployLimitOfReserve[ _protocol ] = newLimitOfReserve[ _protocol ];
        newLimitOfReserve[ _protocol ] = 0;
        newLimit[ _protocol ] = 0;
        raiseLimitTimelockEnd[ _protocol ] = 0;
    }

    /**
    * @notice calculate amount to be deployed
    */
    function amountToBeDeployed(address _protocol, uint _amountInUSDC) public returns (uint) {
        require(_protocol != address(0), "Protocol address can't be zero address");
        require(_amountInUSDC != 0, "Input value can't be zero");
        uint totalReserveTreasury = treasury.totalReserves();
        uint value = totalReserveTreasury.mul(deployLimitOfReserve[_protocol]).div(10000);
        uint netValue = value.sub((treasury.valueOf( USDC, _amountInUSDC)).add(deployedFor[_protocol]));
        uint netAmount = netValue.div(1e12); // netAmount is in the form of USDC

        if (netAmount <= 0) {
            return 0;
        }
        if (netAmount > _amountInUSDC) {
            return _amountInUSDC;
        } else {
            uint balanceInTreasury = IERC20( USDC ).balanceOf(address(treasury));
            uint newNetAmount = netAmount.add(balanceInTreasury);

            if (newNetAmount >= _amountInUSDC) {
                uint transferUSDC = _amountInUSDC.sub(netAmount);
                treasury.manage( USDC, transferUSDC ); // retrieve difference USDC from treasury

                return _amountInUSDC;
            } else {
                return netAmount;
            }
        }
    }

    /**
     *  @notice accounting of deposits/withdrawals of assets
     *  @param _value uint
     *  @param _add bool
     */
    function accountingFor( address _protocol, uint _value, uint256 _balance, bool _add ) internal {
        if( _add ) {
            deployedFor[ _protocol ] = deployedFor[ _protocol ].add( _value ); // track amount allocated into pool

            rewardBalance[ _protocol ] = rewardBalance[ _protocol ].add(_balance);
        
            totalValueDeployed = totalValueDeployed.add( _value ); // track total value allocated into pools
            
        } else {
            // track amount allocated into pool
            if ( _value < deployedFor[ _protocol ] ) {
                deployedFor[ _protocol ] = deployedFor[ _protocol ].sub( _value ); 
            } else {
                deployedFor[ _protocol ] = 0;
            }
            
            // track total value allocated into pools
            if ( _value < totalValueDeployed ) {
                totalValueDeployed = totalValueDeployed.sub( _value );
            } else {
                totalValueDeployed = 0;
            }
        }
    }
}