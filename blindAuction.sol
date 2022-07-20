pragma solidity >=0.7.0 <0.9.0;
// SPDX-License-Identifier: GPL-3.0

contract BlindAuction{

    address payable public beneficiary;
    uint public bidTime;
    uint public revealTime;
    bool public ended;
   
    struct bid {
        bytes32 blindedbid;
        uint deposit;
    }
    
    mapping(address=>bid[]) public list;

    address public highestBidder;
    uint public highestBid;

    mapping(address=>uint) public pendingList;

    event auctionEnded(address highestBidder, uint highestBid);

    error tooLate(uint _time);
    error tooEarly(uint _time);
    error auctionEndAlreadyCalled();

    modifier onlyBefore(uint _time) {
        if(block.timestamp >= _time) revert tooLate(_time);
        _;
    }

    modifier OnlyAfter(uint _time) {
        if(block.timestamp <= _time) revert tooEarly(_time);
        _;
    }

    constructor(address payable _beneficiary,uint _bidTime,uint _revealTime) public 
    {
        beneficiary = _beneficiary;
        bidTime = block.timestamp + _bidTime;
        revealTime = bidTime + _revealTime;
    }

    function Bid(bytes32 _blindedbid) external  payable onlyBefore(bidTime)
    {
      list[msg.sender].push( bid({blindedbid : _blindedbid ,
      deposit  : msg.value}));
    }


    function reveal(uint[] calldata values,bool[] calldata fakes,uint[] calldata nonces) external OnlyAfter(bidTime) onlyBefore(revealTime)
    {
       uint length = list[msg.sender].length;
       require(values.length == length);
       require(fakes.length == length);
       require(nonces.length == length);
       
       for(uint i = 0 ; i < length ; i++) 
       {
           uint refund;
           bid storage bidToCheck = list[msg.sender][i];
           (uint value,bool fake,uint nonce) = (values[i], fakes[i],nonces[i]);
           if( keccak256(abi.encodePacked(value,fake,nonce)) !=  bidToCheck.blindedbid ) { continue; }
           refund += bidToCheck.deposit;
           if(!fake && value >= bidToCheck.deposit)
           { 
               if(placeBid(msg.sender,value)) { refund -= value ; }
               bidToCheck.blindedbid = bytes32(0); 
           }
           payable(msg.sender).transfer(refund);
       }
    }

    function placeBid(address bidder, uint value) internal returns(bool success){

        if(value <= highestBid){
            return false;
        }
        if(highestBidder != address(0)){
            pendingList[highestBidder] += highestBid;
        }
        highestBid =value;
        highestBidder = bidder;
    }
    
    function auctionEnd() external  {
       
        ended = true;
        beneficiary.transfer(highestBid);
    }
    function withDraw() external {
       uint amount = pendingList[msg.sender] ;
       pendingList[msg.sender] = 0;
       if(amount > 0){
       payable(msg.sender).transfer(amount);
       }
    }

    function generateBid(uint value, bool fake , uint secret) public pure returns  (bytes32 bidg) {
         bidg = keccak256(abi.encodePacked(value, fake, secret));
         return bidg;
    }
}
