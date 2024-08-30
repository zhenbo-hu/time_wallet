# 钱包合约

## 功能

- Owner 可以通过 `withdraw` 方法提取钱包中的 token
- 每 24 小时提取限制总额度为 `100 * 1e6`
- 单次提取限制额度为 `50 * 1e6`

## 核心逻辑

通过多个 `modifier` 来检查资金提取的时间间隔、每次提取金额、24 小时内提取总金额等信息。

`checkTokenAmount` 用于检查当前合约是否拥有所需数量的 token

```solidity
modifier checkTokenAmount(uint256 amount) {
    if (ERC20(TOKEN_ADDRESS).balanceOf(address(this)) < amount)
        revert NoEnoughTokenAmount();
    _;
}
```

`checkWithdrawAmountLimitPerTime` 用于检查是否超过单次提取额度上限

```solidity
modifier checkWithdrawAmountLimitPerTime(uint256 amount) {
    if (amount > WITHDRAW_AMOUNT_LIMIT_PER_TIME)
        revert WithdrawAmountLimitPerTimeReached();
    _;
}
```

`checkWithdrawTimeIntervalAndAmount` 用于检查是否满足过去 24 小时总提取额度限制

定义 `WithdrawRecord` 结构体和 `WithdrawRecord[] private withdrawRecords;` 状态变量，用于记录每次提取的时间戳和金额

```solidity
struct WithdrawRecord {
    uint256 timestamp;
    uint256 amount;
}

WithdrawRecord[] private withdrawRecords;
```

### 方法 1

每次提取时，从 `withdrawRecords` 数组中倒序遍历，直到找到最近一次提取的时间戳加上 `WITHDRAW_INTERVAL` 小于等于当前时间戳的记录，或者遍历完整个数组。

每次都需遍历数组，时间复杂度为 $O(n)$

**注意**：为防止倒序查找时数组越界，`index=0` 在初始化合约时赋值为空值，真正的提取记录从 1 开始

```solidity
modifier checkWithdrawTimeIntervalAndAmount(
    uint256 currentTime,
    uint256 amount
) {
    uint256 currentWithdrawAmount = 0;
    uint256 i = withdrawRecords.length - 1;
    for (; i > 0; --i) {
        if (withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <= currentTime)
            break;
        if (
            currentWithdrawAmount + withdrawRecords[i].amount + amount >
            WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL
        ) revert WithdrawAmountLimitPerIntervalReached();
        currentWithdrawAmount += withdrawRecords[i].amount;
    }

    _;
}

function withdraw(
    uint256 amount
)
    external
    onlyOwner
    checkTokenAmount(amount)
    checkWithdrawAmountLimitPerTime(amount)
    checkWithdrawTimeIntervalAndAmount(block.timestamp, amount)
{
    withdrawRecords.push(WithdrawRecord(block.timestamp, amount));

    ERC20(TOKEN_ADDRESS).transfer(msg.sender, amount);
    emit Withdraw(msg.sender, block.timestamp, amount);
}
```

### 方法 2

利用 `index=0` 没有被用到的特点，用于记录上一次提取时同一天的全部提取金额和最初提取记录所在的 index。这样对于在 24 小时内的提取行为，不需要遍历数组，可以直接判断。当超过 24 小时时，再遍历数组，更新数据。

理想情况下，每次均可在固定操作步骤内得到结果，时间复杂度为 $O(1)$

最坏情况下，需要遍历数组才能够得到结果，时间复杂度为 $O(n)$

```solidity
modifier checkWithdrawTimeIntervalAndAmount(
    uint256 currentTime,
    uint256 amount
) {
    uint256 lastestIndex = withdrawRecords[0].timestamp;
    uint256 lastestAmounts = withdrawRecords[0].amount;
    uint256 recordsLength = withdrawRecords.length;

    if (
        lastestIndex != 0 &&
        withdrawRecords[lastestIndex].timestamp + WITHDRAW_INTERVAL <=
        currentTime
    ) {
        uint256 i = lastestIndex;
        do {
            lastestAmounts -= withdrawRecords[i++].amount;
        } while (
            i < recordsLength &&
                withdrawRecords[i].timestamp + WITHDRAW_INTERVAL <=
                currentTime
        );

        if (i < recordsLength) {
            withdrawRecords[0] = WithdrawRecord(i, lastestAmounts);
        } else {
            withdrawRecords[0] = WithdrawRecord(0, 0);
        }
    }

    if (lastestAmounts + amount > WITHDRAW_AMOUNT_LIMIT_PER_INTERVAL)
        revert WithdrawAmountLimitPerIntervalReached();

    _;
}

function withdraw(
    uint256 amount
)
    external
    onlyOwner
    checkTokenAmount(amount)
    checkWithdrawAmountLimitPerTime(amount)
    checkWithdrawTimeIntervalAndAmount(block.timestamp, amount)
{
    withdrawRecords.push(WithdrawRecord(block.timestamp, amount));

    withdrawRecords[0].amount += amount;
    if (withdrawRecords[0].timestamp == 0)
        withdrawRecords[0].timestamp = withdrawRecords.length - 1;


    ERC20(TOKEN_ADDRESS).transfer(msg.sender, amount);
    emit Withdraw(msg.sender, block.timestamp, amount);
}
```

## gas 消耗分析

为于 `ERC20` 转账做对比，这里实现了一个简单的 ERC20 合约：[USDT.sol](./src/USDT.sol)。

利用 `foundry test --gas-report` 估计 gas 消耗情况：

- ERC20 `transfer` 平均 gas : `34461`
- 方法 1 `withdraw` 平均 gas : `106525`, 约 3.09 倍
- 方法 2 `withdraw` 平均 gas : `100104`, 约 2.90 倍

### 方法 1 gas report

```shell
$ forge test --gas-report
[⠊] Compiling...
[⠊] Compiling 2 files with Solc 0.8.26
[⠒] Solc 0.8.26 finished in 925.62ms
Compiler run successful!

Ran 1 test for test/USDT.t.sol:USDTTest
[PASS] testTransfer() (gas: 56509)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 6.07ms (976.71µs CPU time)

Ran 11 tests for test/TimeWallet.t.sol:TimeWalletTest
[PASS] testConstructor() (gas: 413286)
[PASS] testWithdraw() (gas: 111544)
[PASS] testWithdrawAllUsdtMultiTimeOver1DayRevertNoEnoughTokenAmount() (gas: 5651708)
[PASS] testWithdrawAllUsdtMultiTimeOver1DaySuccessful() (gas: 5618544)
[PASS] testWithdrawLess100UsdtMultiTimeLess1DaySuccessful() (gas: 213965)
[PASS] testWithdrawLess100UsdtOneTimeLess1DaySuccessful() (gas: 119645)
[PASS] testWithdrawOver100UsdtMultiTimeOver1DaySuccessful() (gas: 387961)
[PASS] testWithdrawOver100UsdtMultiTimesLess1DayRevertWithdrawAmountLimitPerIntervalReached() (gas: 459890)
[PASS] testWithdrawOver100UsdtMultiTimesOver1DayRevertWithdrawAmountLimitPerIntervalReached() (gas: 682899)
[PASS] testWithdrawOver50UsdtOneTimeRevert() (gas: 43049)
[PASS] testWithdrawRevertNotOwner() (gas: 38017)
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 8.73ms (19.05ms CPU time)
| src/TimeWallet.sol:TimeWallet contract |                 |        |        |        |         |
|----------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                        | Deployment Size |        |        |        |         |
| 373784                                 | 1668            |        |        |        |         |
| Function Name                          | min             | avg    | median | max    | # calls |
| OWNER                                  | 204             | 204    | 204    | 204    | 1       |
| TOKEN_ADDRESS                          | 182             | 182    | 182    | 182    | 1       |
| withdraw                               | 21564           | 106525 | 107701 | 139855 | 123     |




Ran 2 test suites in 14.73ms (14.80ms CPU time): 12 tests passed, 0 failed, 0 skipped (12 total tests)
```

### 方法 2 gas report

```shell
$ forge test --gas-report
[⠢] Compiling...
[⠒] Compiling 3 files with Solc 0.8.26
[⠢] Solc 0.8.26 finished in 1.87s
Compiler run successful!

Ran 1 test for test/USDT.t.sol:USDTTest
[PASS] testTransfer() (gas: 56509)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 6.01ms (998.83µs CPU time)

Ran 11 tests for test/TimeWallet.t.sol:TimeWalletTest
[PASS] testConstructor() (gas: 500879)
[PASS] testWithdraw() (gas: 157313)
[PASS] testWithdrawAllUsdtMultiTimeOver1DayRevertNoEnoughTokenAmount() (gas: 5119776)
[PASS] testWithdrawAllUsdtMultiTimeOver1DaySuccessful() (gas: 5086612)
[PASS] testWithdrawLess100UsdtMultiTimeLess1DaySuccessful() (gas: 265049)
[PASS] testWithdrawLess100UsdtOneTimeLess1DaySuccessful() (gas: 165414)
[PASS] testWithdrawOver100UsdtMultiTimeOver1DaySuccessful() (gas: 461424)
[PASS] testWithdrawOver100UsdtMultiTimesLess1DayRevertWithdrawAmountLimitPerIntervalReached() (gas: 491612)
[PASS] testWithdrawOver100UsdtMultiTimesOver1DayRevertWithdrawAmountLimitPerIntervalReached() (gas: 709161)
[PASS] testWithdrawOver50UsdtOneTimeRevert() (gas: 43049)
[PASS] testWithdrawRevertNotOwner() (gas: 38017)
Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 8.70ms (18.22ms CPU time)
| src/TimeWallet.sol:TimeWallet contract |                 |        |        |        |         |
|----------------------------------------|-----------------|--------|--------|--------|---------|
| Deployment Cost                        | Deployment Size |        |        |        |         |
| 461302                                 | 2074            |        |        |        |         |
| Function Name                          | min             | avg    | median | max    | # calls |
| OWNER                                  | 204             | 204    | 204    | 204    | 1       |
| TOKEN_ADDRESS                          | 182             | 182    | 182    | 182    | 1       |
| withdraw                               | 21564           | 100104 | 99898  | 152105 | 123     |




Ran 2 test suites in 14.81ms (14.71ms CPU time): 12 tests passed, 0 failed, 0 skipped (12 total tests)
```

- ERC20 transfer 的 gas 消耗

```shell
$ forge test --match-test testTransfer --gas-report
[⠊] Compiling...
No files changed, compilation skipped

Ran 2 tests for test/USDT.t.sol:USDTTest
[PASS] testTransfer() (gas: 56509)
[PASS] testTransferMultiTimes() (gas: 3486595)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 11.23ms (5.42ms CPU time)
| src/USDT.sol:USDT contract |                 |       |        |       |         |
|----------------------------|-----------------|-------|--------|-------|---------|
| Deployment Cost            | Deployment Size |       |        |       |         |
| 737958                     | 3666            |       |        |       |         |
| Function Name              | min             | avg   | median | max   | # calls |
| transfer                   | 29370           | 34461 | 34170  | 51282 | 101     |




Ran 1 test suite in 21.01ms (11.23ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```
