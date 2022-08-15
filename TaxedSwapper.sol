//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./Ownable.sol";

contract TaxedSwapper is Ownable {

    // Token To Swap
    address public immutable token;

    // Fees
    uint256 public fee;
    address public destination;

    // router
    IUniswapV2Router02 public router;

    // path
    address[] path;

    constructor(address _token, address _destination, address _DEX, uint256 _fee) {
        token = _token;
        destination = _destination;
        router = IUniswapV2Router02(_DEX);
        fee = _fee;
        path = new address[](2);
        path[0] = router.WETH();
        path[1] = _token;
    }
    function setRouter(address _router) external onlyOwner {
        router = IUniswapV2Router02(_router);
    }
    function setFee(uint _fee) external onlyOwner {
        fee = _fee;
    }
    function setDestination(address _destination) external onlyOwner {
        require(_destination != address(0), 'Zero Destination');
        destination = _destination;
    }
    function withdraw(address _token) external onlyOwner {
        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));
    }

    function withdraw() external onlyOwner {
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }

    function buyToken(address recipient, uint minOut) external payable {
        _buyToken(recipient, msg.value, minOut);
    }

    function buyToken(address recipient) external payable {
        _buyToken(recipient, msg.value, 0);
    }

    function buyToken() external payable {
        _buyToken(msg.sender, msg.value, 0);
    }

    receive() external payable {
        _buyToken(msg.sender, msg.value, 0);
    }

    function _buyToken(address recipient, uint value, uint minOut) internal {
        require(
            value > 0,
            'Zero Value'
        );
        require(
            recipient != address(0),
            'Recipient Cannot Be Zero'
        );

        uint _fee = ( value * fee ) / 100;
        _send(destination, _fee);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
            minOut,
            path,
            address(this),
            block.timestamp + 300
        );
        IERC20(token).transfer(
            recipient,
            IERC20(token).balanceOf(address(this))
        );
    }

    function _send(address to, uint val) internal {
        (bool s,) = payable(to).call{value: val}("");
        require(s);
    }
}