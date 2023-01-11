// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract EcommerceStore{
    //商品的状态
    enum ProductStatus{Open,Sold,UnSold}
    //商品的状况
    enum ProductCondition{New ,Used}
    //商品的下标
    uint public productIndex;
    //商品id对应的创建者
    mapping(uint=>address) productIdInStore;
    //创建者对应的id的商品
    mapping(address => mapping(uint  =>Product)) stores;

    mapping(address => mapping(bytes32 => Bid)) bids;

    //竞拍者
    struct Bid{
        address bidder;
        uint productId;
        uint value;
        bool revealed;
    } 
    //商品
    struct Product{
        uint id;
        string  name;
        string category;
        string imageLink;
        string descLink;
        uint auctionStartTime;
        uint auctionEndTime;
        uint startPrice;
        address highestBidder;
        uint highestBid;
        uint secondHighestBid;
        uint totalBids;
        ProductStatus status;
        ProductCondition condition;
    }


    constructor () {
        productIndex = 0;
    }

    //添加商品
    function addProductToStore(string memory _name,string memory _category,string memory _imageLink,string memory _descLink,uint _auctionStartTime, uint _auctionEndTime,uint _startPrice,uint _productCondition) public {
        require(_auctionStartTime < _auctionEndTime,"Acction start time should be earlier than end time.");
        productIndex += 1;
        Product memory product = Product(productIndex,_name,_category,_imageLink,_descLink,_auctionStartTime,_auctionEndTime,_startPrice,address(0),0,0,0,ProductStatus.Open,ProductCondition(_productCondition));
        stores[msg.sender][productIndex] = product;
        productIdInStore[productIndex] = msg.sender;     
    }

    function getProduct(uint _productId) public view returns(uint,string memory,string memory,string memory,string memory,uint,uint,uint,ProductStatus,ProductCondition){
        Product memory product = stores[productIdInStore[_productId]][_productId];
        return (product.id,product.name,product.category,product.imageLink,product.descLink,product.auctionStartTime,product.auctionEndTime,product.startPrice,product.status,product.condition);
    }
    //竞拍出价
    function bid(uint _productId,bytes32 _bid) public payable returns(bool){
        Product storage product = stores[productIdInStore[_productId]][_productId];
        require(block.timestamp >= product.auctionStartTime,"Current time should be later than auction start time");
        require(block.timestamp <= product.auctionEndTime,"Current time should be earlier than auction end time");
        require(msg.value > product.startPrice,"Value should be larger than start price");
        require(bids[msg.sender][_bid].bidder == address(0),"Bid should be null");
        bids[msg.sender][_bid] = Bid(msg.sender,_productId,msg.value,false);
        product.totalBids += 1;
        return true;
    }


    //揭示报价
    function revealBid(uint _productId,uint  _amount,string memory _secret)  public {
        //获取商品
        Product storage product = stores[productIdInStore[_productId]][_productId];
        require(block.timestamp > product.auctionEndTime);
        //拿到bid
        bytes32 sealedBid = keccak256(abi.encode(_amount,_secret));
        Bid memory bidInfo = bids[msg.sender][sealedBid];
        require(bidInfo.bidder > address(0),"Bidder should exist");
        require(bidInfo.revealed == false,"Bid should not be revealed");

        uint refund;
        uint amount = _amount;
        if(bidInfo.value <amount){
            refund = bidInfo.value;
        }else{
            if(address(product.highestBidder)==address(0)){
                product.highestBidder = msg.sender;
                product.highestBid = amount;
                product.secondHighestBid = product.startPrice;
                refund = bidInfo.value - amount;
            }else{
                //比最高价要高
                if(amount > product.highestBid){
                      // 將原來的最高價賦值給第二高價
                    product.secondHighestBid = product.highestBid;
                    // 將原來最高的出價退給原先的最高價地址
                    payable(product.highestBidder).transfer(product.highestBid);
                     // 將當前出價者的地址做爲最高價地址
                    product.highestBidder = msg.sender;
                    // 將當前出價做爲最高價，爲15
                    product.highestBid = amount;
                    refund = bidInfo.value - amount;
                }else if (amount > product.secondHighestBid) {
                    //第二高报价
                    product.secondHighestBid = amount;
                    refund = amount;
                }else {
                    //比第二高报价要低
                     refund = amount;
                }
            }
        }
        //退款
        if(refund >0){
            payable(msg.sender).transfer(refund);
            bids[msg.sender][sealedBid].revealed = true;
        }
    }


    //获取最高报价者
    function highestBidderInfo (uint _productId)public view returns (address, uint ,uint) {
        Product memory product = stores[productIdInStore[_productId]][_productId];
         return (product.highestBidder,product.highestBid,product.secondHighestBid);
    }

     //2. 獲取參與競標的人數
        function  totalBids(uint _productId) view public returns (uint) {
        Product memory product = stores[productIdInStore[_productId]][_productId];
        return product.totalBids;
        }

}
