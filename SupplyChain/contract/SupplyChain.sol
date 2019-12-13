pragma solidity >=0.4.22<0.7.0;
contract SupplyChain{
    int[3] credits=[999,100,50];
    struct company{
        uint ID; //公司id
        string name;//公司名字
        uint attr;//公司性质(0:银行；1：核心企业；2：供应商)
        uint balance;
        int credit;//公司信用
        mapping(uint => receipt) sellReceipts;//出售的单据
        mapping(uint => receipt) purchaseReceipts;//购买的单据
    }
    mapping(address => company) public companies;//每个公司对应地址
    mapping(string => address) NamesOfCompanies;//地址和名字的映射
    company[] comArry;//避免有相同id的公司注册

    struct receipt {
        uint ID;//单据ID
	    string from ;// 欠款人
	    string to ;// 收款人
	    uint amount; // 金额
        string signTime;//签订时间
        string expiredTime;//还款到期时间
	    bool status; // 状态，例如银行参与确认了这笔交易，可以变为某个状态，可信度更高
        //如果查到其信誉值达到标准或者是手里有值得信任的收据则银行可以与其打款
    }

  

    function giveRightToCom(address companyAddr,uint companyid,string memory companyName,uint comattr,uint ba) public returns(bool){

        company storage temp = companies[companyAddr];
        temp.ID=companyid;
        temp.name=companyName;
        temp.attr=comattr;//公司的性质是在创建它的时候给的
        temp.balance=ba;
        temp.credit=credits[comattr];
        companies[companyAddr]=temp;
        NamesOfCompanies[companyName]=companyAddr;

        return (true);
    }
    function purchase(uint recID,address supplier,uint mount,bool stat,string memory _signTime,string memory _expiredTime) public returns(uint){
        if(companies[supplier].ID == 0x0){
            return (0);
        }
        company storage f = companies[msg.sender];
        company storage t = companies[supplier];
        receipt memory r = receipt({
            ID: recID,
            from: f.name,
            to: t.name,
            amount: mount,
            signTime: _signTime,
            expiredTime: _expiredTime,
            status: stat//交易有没有被作证是在交易被创建的时候确定的
        });

        t.sellReceipts[recID]=r;
        f.purchaseReceipts[recID]=r;
        return (f.purchaseReceipts[recID].ID);


      
    }
    function receiptTrans(uint mount,uint oldSellID,uint oldPurID,uint newID,string memory transTime)public returns(bool,string memory, uint){

     
        address former= NamesOfCompanies[companies[msg.sender].sellReceipts[oldSellID].from];
        address latter= NamesOfCompanies[companies[msg.sender].purchaseReceipts[oldPurID].to];
   

        
        if(companies[msg.sender].sellReceipts[oldSellID].ID == 0x0){
            return (false,"Sell Receipt with company doesn't exsit!",0x0);
        }
        if(companies[msg.sender].purchaseReceipts[oldPurID].ID == 0x0){
            return (false,"Purchase Receipt with company  doesn't exsit!",0x0);
        }
        if(companies[msg.sender].sellReceipts[oldSellID].amount<mount){
            return (false,"Trade Receipt less than required!",0x0);
        }

        if(companies[former].purchaseReceipts[newID].ID!=0x0 || companies[latter].sellReceipts[newID].ID!=0x0){
            return(false,"New Receipt ID already exsits!",0x0);
        }
        companies[former].purchaseReceipts[oldSellID].amount-=mount;
        companies[msg.sender].sellReceipts[oldSellID].amount-=mount;
        if(companies[msg.sender].sellReceipts[oldSellID].amount==0){
            delete companies[msg.sender].sellReceipts[oldSellID];
            delete companies[former].purchaseReceipts[oldSellID];
        }
        companies[latter].sellReceipts[oldPurID].amount-=mount;
        companies[msg.sender].purchaseReceipts[oldPurID].amount-=mount;
        if(companies[msg.sender].purchaseReceipts[oldPurID].amount==0){
            delete companies[msg.sender].purchaseReceipts[oldPurID];
            delete companies[latter].sellReceipts[oldPurID];
        }

        receipt memory r = receipt({
            ID: newID,
            from: companies[former].name,
            to: companies[latter].name,
            amount: mount,
            signTime: transTime,
            expiredTime:  companies[latter].sellReceipts[oldPurID].expiredTime,//还款日期是根据latter的还款日期确定
            status: companies[former].purchaseReceipts[oldSellID].status//交易有没有被作证是根据former的收据是否被认证确定
        });     
        companies[latter].sellReceipts[newID]=r;
        companies[former].purchaseReceipts[newID]=r;      
        return (true,"Transfer Receipt succussfully!",newID);

    }

    function financing(address receiver,uint fReceipt) public returns(int){
        if(companies[msg.sender].attr!=0){
          //  return (false,"Only banks can give balances to companies.");
          return (1);
        }
        if(companies[receiver].credit<60&&companies[receiver].sellReceipts[fReceipt].status!=true){
           // return (false,"Only finance to trusted companies");
           return (2);
        }

        companies[receiver].balance+=companies[receiver].sellReceipts[fReceipt].amount;
        //债权转让
        company storage debtor = companies[NamesOfCompanies[companies[receiver].sellReceipts[fReceipt].from]];
        debtor.purchaseReceipts[fReceipt].to = companies[msg.sender].name;
        delete companies[receiver].sellReceipts[fReceipt];
        //return (true,"Finance succussfully!");
        return (3);
    }


    function settle(uint sReceipt,string memory timeN) public returns(bool,string memory){
        company storage thisCom=companies[msg.sender];
        company storage creditor=companies[NamesOfCompanies[companies[msg.sender].purchaseReceipts[sReceipt].to]];
        if(thisCom.balance<thisCom.purchaseReceipts[sReceipt].amount){
            thisCom.credit-=10;
            return (false,"company's balance is not enough to settle this debt.");
        }
        thisCom.balance-=thisCom.purchaseReceipts[sReceipt].amount;
        creditor.balance+=thisCom.purchaseReceipts[sReceipt].amount;
        delete thisCom.purchaseReceipts[sReceipt];
        delete creditor.sellReceipts[sReceipt];
        if(keccak256(abi.encodePacked(companies[msg.sender].purchaseReceipts[sReceipt].expiredTime))<keccak256(abi.encodePacked(timeN))){
            thisCom.credit-=10;
            return (true,"company settle debt out of expired time");
        }
        thisCom.credit+=10;
        return (true,"company settle debt succussfully!");
    }
    function getBalance() public returns(uint){
        return (companies[msg.sender].balance);
    }

}





