#合约说明

##ContractHouse
本合约为管理合约，可以进行新合约的创建和已有合约的查询

###method
```
{
	//买家钱包地址，产品金额，产品描述，首付比例（50意味着50%），分期数
	"712be6bd": "createContract(address,uint256,string,uint8,uint8)",
	//返回对应钱包地址有关的所有合同的时间戳
	"ccdaf277": "getContractTimestamps(address)",
	//通过key查找对应分期合同的地址，key=“钱包地址:时间戳”
	"ce29af78": "getUserContracts(string)"
}
```
##InstalmentBuyContract
本合约为一份分期购合约，保存有一次订单的所有状态

```
{
	//设置转卖价格
	"10388809": "setTransferPrice(uint256)",
	//购买转让产品所有权
	"cebd4b36": "buyOwnerShip(address,uint256)",
	//获得实际分期金额列表
	"7558bd2f": "getActualInstalMentBills()",
	//查询合约地址余额
	"12065fe0": "getBalance()",
	//获取当前分期数
	"8cfc1570": "getCurrentInstalmentNo()",
	//获取当前所有产品地址
	"d169656f": "getCurrentProductOwnerAddr()",
	//查询操作日志
	"ba71f1cb": "getInfoLog(uint256)",
	//获取计划分期金额列表
	"cac7da66": "getInstalMentBills()",
	//返回上一次分期支付时间戳
	"c1c244e8": "getLastTimeStamp()",
	//返回下一次分期支付信息（金额，预定还款时间戳）
	"0eeaea28": "getNextInstalmentPayInfo()",
	//返回下一次还款时间戳
	"0c4b12de": "getNextTimeStamp()",
	//返回已支付金额
	"c072d6b5": "getPaidMoney()",
	//返回产品描述
	"e01e6701": "getProductDesc()",
	//返回产品金额
	"542540ce": "getProductPrice()",
	//返回总的日志数
	"982002da": "getTotalInfoLogsCount()",
	//返回总的分期数
	"ad0d6d13": "getTotalInstalmentCount()",
	//获取转卖价格
	"88303e97": "getTransferPrice()",
	//分期付款，包括首次付款，
	"d1488929": "payInstalment(address,uint256)"
}
```

##DateTime
##SafeMath
##StringExtend
这几个为使用到的库

#测试说明
合约已经通过remix发布到kovan测试网络，由于合约中有些方法涉及到权限判断，因此，你可以自己发布。也可以使用我提供的钱包地址。

```
钱包地址：0x426af9045c7b6970fb08e760ec0dabca74cd418c

已发表合约地址：
ContractHouse 
0x8c860524282d220396f345725e3fe07391c95473

某一份InstalmentBuyContract 
0x717d02F374320950f26A85ED81A120e7d473e76e
```

