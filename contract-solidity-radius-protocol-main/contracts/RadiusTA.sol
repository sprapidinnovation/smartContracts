// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRadius.sol";

contract RadiusTAUniverisy is ERC1155, Ownable {
    IRadius private token;
    uint256 public tokenIdCounter;

    enum Currency {
        RADIUS,
        NATIVE
    }

    struct Item {
        string metadata;
        uint256 price;
        Currency currency;
        uint256 soldCount;
    }

    uint256 public minimumTokenBalance;

    mapping(uint256 => Item) public items;
    mapping(string => uint256) public itemId;
    mapping(uint256 => string) private tokenURI;

    event ItemAdded(
        uint256 id,
        string metadata,
        uint256 price,
        Currency currency
    );
    event ItemUpdated(uint256 id, uint256 price, Currency currency);
    event ItemRemoved(uint256 id);
    event ItemBought(uint256 id);

    constructor(address _token, uint256 _minimumTokenBalance)
        ERC1155("https://ipfs.io/ipfs/")
    {
        token = IRadius(_token);
        minimumTokenBalance = _minimumTokenBalance;
    }

    function addItem(
        string memory _metadata,
        uint256 _price,
        Currency _currency
    ) external onlyOwner {
        require(itemId[_metadata] == 0, "Item already added");

        itemId[_metadata] = ++tokenIdCounter;
        items[tokenIdCounter] = Item(_metadata, _price, _currency, 0);
        tokenURI[tokenIdCounter] = _metadata;

        emit ItemAdded(tokenIdCounter, _metadata, _price, _currency);
    }

    function updateItemPrice(
        uint256 _id,
        uint256 _price,
        Currency _currency
    ) external onlyOwner {
        Item storage item = items[_id];

        require(itemId[item.metadata] != 0, "Item does not exist");

        item.price = _price;
        item.currency = _currency;

        emit ItemUpdated(_id, _price, _currency);
    }

    function removeItem(uint256 _id) external onlyOwner {
        require(itemId[items[_id].metadata] != 0, "Item does not exist");

        delete itemId[items[_id].metadata];
        delete items[_id];

        emit ItemRemoved(_id);
    }

    function buyItem(uint256 _id) external payable {
        Item memory item = items[_id];

        require(itemId[item.metadata] != 0, "Item does not exist");
        require(
            token.balanceOf(msg.sender) >= minimumTokenBalance,
            "Not enough Radius tokens"
        );

        items[_id].soldCount++;

        if (item.currency == Currency.NATIVE) {
            require(msg.value >= item.price, "Insufficient funds sent");

            payable(msg.sender).transfer(msg.value - item.price);
        } else {
            token.transferFrom(msg.sender, address(this), item.price);
        }

        _mint(msg.sender, _id, 1, "");
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return tokenURI[_id];
    }

    function updateMinimumTokenBalance(uint256 _minTokenBalance)
        external
        onlyOwner
    {
        minimumTokenBalance = _minTokenBalance;
    }

    receive() external payable {}

    function withdraw(address payable _address) external onlyOwner {
        require(_address != address(0), "Cannot transfer to zero address");

        _address.transfer(address(this).balance);
        token.transfer(_address, token.balanceOf(address(this)));
    }
}
