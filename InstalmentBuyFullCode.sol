pragma solidity ^0.4.17;


contract ContractHouse{
    using StringExtend for string;
    address owner;
    mapping(string => address) contracts;
    mapping(address =>uint[]) userTimestamps;

    constructor(address _contract_owner) public {
        owner = _contract_owner;
    }

    function createContract(address _buyerAddress,uint _productPrice ,string _productDesc, uint8 _firstPayRate,uint8 _totalInstalmentCount) public onlyOwner payable returns(address) {
        address addr = new InstalmentBuyContract(owner,_buyerAddress,_productPrice,_productDesc,_firstPayRate,_totalInstalmentCount);
        string memory addrStr = addressToAsciiString(_buyerAddress);
        uint timestamp = now;
        string memory timestampStr = uint2str(timestamp);
        string memory result = addrStr.concat(":");
        result = result.concat(timestampStr);
        contracts[result] = addr;
        userTimestamps[_buyerAddress].push(timestamp);
        return addr;
    }

    function getContractTimestamps(address _addr) public view returns (uint[]) {
        return userTimestamps[_addr];
    }

    function getUserContracts(string _key) public view returns(address) {
        return contracts[_key];
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    //utils
    function addressToAsciiString(address x)internal pure returns (string) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
            byte hi = byte(uint8(b) / 16);
            byte lo = byte(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
        }
        return string(s);
    }

    function char(byte b)internal pure returns (byte c) {
        if (b < 10) return byte(uint8(b) + 0x30);
        else return byte(uint8(b) + 0x57);
    }

    function uint2str(uint i) internal pure returns (string){
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0){
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint k = length - 1;
        while (i != 0){
            bstr[k--] = byte(48 + i % 10);
            i /= 10;
        }
        return string(bstr);
    }
}

contract InstalmentBuyContract {

    using SafeMath for uint;

    address contract_owner;
    address currentProductOwnerAddr;
    uint8 currentInstalmentNo;
    uint8 totalInstalmentCount;
    uint productPrice;
    string productDesc;
    uint paidMoney;
    uint8 firstPayRate;

    uint createTimeStamp;
    uint lastTimeStamp;
    uint nextTimeStamp;

    uint[] instalmentBills;
    uint[] actualInstalmentBills;

    struct InfoLog{
        address userAddr;
        uint value;
        string action;
        uint timestamp;
    }

    InfoLog[] infoLogs;
    uint totalInfoLogCount;

    uint transferPrice;
    bool isTransfer = false;

    // uint fixedRate = 1000000000000000000;
    uint fixedRate = 1;

    constructor (address contractOwnerAddr,address buyerAddress,uint _productPrice ,string _productDesc, uint8 _firstPayRate,uint8 _totalInstalmentCount) public payable{
        contract_owner = contractOwnerAddr;
        currentProductOwnerAddr = buyerAddress;
        productPrice = _productPrice *fixedRate;
        productDesc = _productDesc;
        firstPayRate = _firstPayRate;
        totalInstalmentCount = _totalInstalmentCount;
        initInstalMentBills(_productPrice,_firstPayRate,_totalInstalmentCount);
    }

    //init
    function initInstalMentBills(uint _productPrice,uint _firstPayRate,uint _totalInstalmentCount) internal {
        uint firstPay = _productPrice.mul(_firstPayRate).div(100);
        uint instalmentPrice = (_productPrice.sub(firstPay)).div(_totalInstalmentCount);
        uint need = instalmentPrice.add(firstPay);
        instalmentBills.push(need);
        for(uint i=1 ; i<_totalInstalmentCount - 1; i++ ) {
            need = need.add(instalmentPrice);
            instalmentBills.push(instalmentPrice);
        }
        instalmentBills.push(_productPrice.sub(need));
    }


    //time method
    function initTimeStamp() internal {
        createTimeStamp = now;
        lastTimeStamp = createTimeStamp;
    }

    function getNextDays(uint _lastTimeStamp) internal pure returns(uint8) {
        uint16 year = DateTime.getYear(_lastTimeStamp);
        uint8 month = DateTime.getMonth(_lastTimeStamp);
        uint8 daysOfMonth = DateTime.getDaysInMonth(month,year);
        return daysOfMonth;
    }

    function updateTimeStamp(bool isFirst) internal {
        if(isFirst) {
            initTimeStamp();
        }else{
            lastTimeStamp = nextTimeStamp;
        }
        uint8 daysOfMonth = getNextDays(lastTimeStamp);
        nextTimeStamp = lastTimeStamp.add( daysOfMonth * 1 days);
    }


    //instalment method
    function payInstalment(address _buyerAddr,uint _value) public payable onlyContractOwner instalmentPayValid payValid{
        uint paid = _value ;
        if(paid != instalmentBills[currentInstalmentNo]) {
            revert();
        }else{
            updateTimeStamp( currentInstalmentNo == 0 );
            currentInstalmentNo +=1;
            paidMoney = paidMoney.add(paid);
            actualInstalmentBills.push(paid);
            saveLogInfo(_buyerAddr,paid,"instalmentPay");
        }
    }

    function getNextInstalmentPayInfo() public view returns(uint,uint,uint) {
        if(currentInstalmentNo == 0) {
            return(instalmentBills[currentInstalmentNo],0,now);
        }else{
            if(now > nextTimeStamp) {
                uint diff = now.sub(nextTimeStamp);
                uint d = diff.div(86400);
                if(diff.sub(d.mul(86400)) > 0) {
                    d = d.add(1);
                }
                //0.005 tax rate
                uint tax = instalmentBills[currentInstalmentNo].div(200).mul(d);

                return(instalmentBills[currentInstalmentNo],tax,now);
            }else{
                return(instalmentBills[currentInstalmentNo],0,nextTimeStamp);
            }

        }
    }

    //transfer ownership method
    function setTransferPrice(uint _transferPrice) public payable onlyBuyer instalmentPayValid payValid returns(bool){
        transferPrice = _transferPrice.mul(fixedRate);
        isTransfer = true;
        saveLogInfo(msg.sender,_transferPrice,"setTransferPrice");
        return true;
    }

    function getTransferPrice() public view returns (uint){
        return transferPrice;
    }

    function buyOwnerShip(address _buyerAddr,uint _value) public payable onlyContractOwner transferable lockState returns (bool){
        uint value = _value;
        if(value < transferPrice) {
            revert();
            return false;
        }else{
            currentProductOwnerAddr = _buyerAddr;
            transferPrice = 0;
            isTransfer = false;
            saveLogInfo(currentProductOwnerAddr,value,"buyOwnerShip");
            return true;
        }
    }


    //utils
    function saveLogInfo(address _addr,uint _value,string _info) internal {
        infoLogs.push(InfoLog(_addr,_value,_info,now));
        totalInfoLogCount = totalInfoLogCount.add(1);
    }


    //getter

    function getNextTimeStamp() public view returns(uint) {
        return nextTimeStamp;
    }

    function getLastTimeStamp() public view returns(uint) {
        return lastTimeStamp;
    }

    function getInstalMentBills() public view returns (uint[]) {
        return instalmentBills;
    }

    function getActualInstalMentBills() public view returns (uint[]) {
        return actualInstalmentBills;
    }

    function getTotalInfoLogsCount() public view returns(uint) {
        return totalInfoLogCount;
    }

    function getInfoLog(uint pos) public constant returns(address addr, uint value,string action, uint time){
        InfoLog storage infoLog = infoLogs[pos];
        return (infoLog.userAddr, infoLog.value, infoLog.action,infoLog.timestamp);
    }

    function getCurrentInstalmentNo() public view returns (uint8) {
        return currentInstalmentNo;
    }

    function getTotalInstalmentCount() public view returns (uint8) {
        return totalInstalmentCount;
    }

    function getProductPrice() public view returns (uint) {
        return productPrice;
    }

    function getProductDesc() public view returns (string) {
        return productDesc;
    }

    function getPaidMoney() public view returns (uint) {
        return paidMoney;
    }


    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getCurrentProductOwnerAddr() public view returns(address) {
        return currentProductOwnerAddr;
    }

    modifier onlyContractOwner {
        require(msg.sender == contract_owner);
        _;
    }

    modifier onlyBuyer {
        require(msg.sender == currentProductOwnerAddr);
        _;
    }

    modifier instalmentPayValid {
        require(currentInstalmentNo < totalInstalmentCount);
        _;
    }

    modifier payValid{
        require(paidMoney < productPrice);
        _;
    }

    modifier transferable {
        require(isTransfer);
        _;
    }

    modifier lockState {
        require(now - nextTimeStamp <0);
        _;
    }
}


library StringExtend {
    function cmp(string old, string value) returns (bool) {
        bytes memory _old = bytes(old);
        bytes memory _value = bytes(value);
        if(_old.length != _value.length) {
            return false;
        }else{
            for(uint i = 0; i < _old.length;i++) {
                if( _old[i] != _value[i]) {
                    return false;
                }
            }
            return true;
        }
    }

    function concat(string old,string value) returns(string) {
        bytes memory _old = bytes(old);
        bytes memory _value = bytes(value);
        bytes memory _ret = new bytes(_old.length + _value.length);
        for(uint i = 0;i<_old.length;i++) {
            _ret[i] = _old[i];
        }
        for(uint j = 0;j<_value.length;j++){
            _ret[_old.length+j] = _value[j];
        }
        return string(_ret);
    }
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}


library DateTime {
        /*
         *  Date and Time utilities for ethereum contracts
         *
         */
        struct _DateTime {
                uint16 year;
                uint8 month;
                uint8 day;
                uint8 hour;
                uint8 minute;
                uint8 second;
                uint8 weekday;
        }

        uint constant DAY_IN_SECONDS = 86400;
        uint constant YEAR_IN_SECONDS = 31536000;
        uint constant LEAP_YEAR_IN_SECONDS = 31622400;

        uint constant HOUR_IN_SECONDS = 3600;
        uint constant MINUTE_IN_SECONDS = 60;

        uint16 constant ORIGIN_YEAR = 1970;

        function isLeapYear(uint16 year) public pure returns (bool) {
                if (year % 4 != 0) {
                        return false;
                }
                if (year % 100 != 0) {
                        return true;
                }
                if (year % 400 != 0) {
                        return false;
                }
                return true;
        }

        function leapYearsBefore(uint year) public pure returns (uint) {
                year -= 1;
                return year / 4 - year / 100 + year / 400;
        }

        function getDaysInMonth(uint8 month, uint16 year) public pure returns (uint8) {
                if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
                        return 31;
                }
                else if (month == 4 || month == 6 || month == 9 || month == 11) {
                        return 30;
                }
                else if (isLeapYear(year)) {
                        return 29;
                }
                else {
                        return 28;
                }
        }

        function parseTimestamp(uint timestamp) internal pure returns (_DateTime dt) {
                uint secondsAccountedFor = 0;
                uint buf;
                uint8 i;

                // Year
                dt.year = getYear(timestamp);
                buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

                secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
                secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

                // Month
                uint secondsInMonth;
                for (i = 1; i <= 12; i++) {
                        secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
                        if (secondsInMonth + secondsAccountedFor > timestamp) {
                                dt.month = i;
                                break;
                        }
                        secondsAccountedFor += secondsInMonth;
                }

                // Day
                for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
                        if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                                dt.day = i;
                                break;
                        }
                        secondsAccountedFor += DAY_IN_SECONDS;
                }

                // Hour
                dt.hour = getHour(timestamp);

                // Minute
                dt.minute = getMinute(timestamp);

                // Second
                dt.second = getSecond(timestamp);

                // Day of week.
                dt.weekday = getWeekday(timestamp);
        }

        function getYear(uint timestamp) public pure returns (uint16) {
                uint secondsAccountedFor = 0;
                uint16 year;
                uint numLeapYears;

                // Year
                year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
                numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

                secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
                secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

                while (secondsAccountedFor > timestamp) {
                        if (isLeapYear(uint16(year - 1))) {
                                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
                        }
                        else {
                                secondsAccountedFor -= YEAR_IN_SECONDS;
                        }
                        year -= 1;
                }
                return year;
        }

        function getMonth(uint timestamp) public pure returns (uint8) {
                return parseTimestamp(timestamp).month;
        }

        function getDay(uint timestamp) public pure returns (uint8) {
                return parseTimestamp(timestamp).day;
        }

        function getHour(uint timestamp) public pure returns (uint8) {
                return uint8((timestamp / 60 / 60) % 24);
        }

        function getMinute(uint timestamp) public pure returns (uint8) {
                return uint8((timestamp / 60) % 60);
        }

        function getSecond(uint timestamp) public pure returns (uint8) {
                return uint8(timestamp % 60);
        }

        function getWeekday(uint timestamp) public pure returns (uint8) {
                return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day) public pure returns (uint timestamp) {
                return toTimestamp(year, month, day, 0, 0, 0);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour) public pure returns (uint timestamp) {
                return toTimestamp(year, month, day, hour, 0, 0);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute) public pure returns (uint timestamp) {
                return toTimestamp(year, month, day, hour, minute, 0);
        }

        function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute, uint8 second) public pure returns (uint timestamp) {
                uint16 i;

                // Year
                for (i = ORIGIN_YEAR; i < year; i++) {
                        if (isLeapYear(i)) {
                                timestamp += LEAP_YEAR_IN_SECONDS;
                        }
                        else {
                                timestamp += YEAR_IN_SECONDS;
                        }
                }

                // Month
                uint8[12] memory monthDayCounts;
                monthDayCounts[0] = 31;
                if (isLeapYear(year)) {
                        monthDayCounts[1] = 29;
                }
                else {
                        monthDayCounts[1] = 28;
                }
                monthDayCounts[2] = 31;
                monthDayCounts[3] = 30;
                monthDayCounts[4] = 31;
                monthDayCounts[5] = 30;
                monthDayCounts[6] = 31;
                monthDayCounts[7] = 31;
                monthDayCounts[8] = 30;
                monthDayCounts[9] = 31;
                monthDayCounts[10] = 30;
                monthDayCounts[11] = 31;

                for (i = 1; i < month; i++) {
                        timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
                }

                // Day
                timestamp += DAY_IN_SECONDS * (day - 1);

                // Hour
                timestamp += HOUR_IN_SECONDS * (hour);

                // Minute
                timestamp += MINUTE_IN_SECONDS * (minute);

                // Second
                timestamp += second;

                return timestamp;
        }
}
