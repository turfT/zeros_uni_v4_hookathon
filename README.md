# Zeros


# Zeros

zeros is a uniswap v4 hook project.
while swap, you can try to generate some zero prefix address.

## Why should I generate zero prefix address?

it flip less bytes in evm, so it cost less gas!

OpenZeppelin erc20 transfer:
  51,486 gas for normal eoa
  50,974 gas for eight zero bytes address

two use case:
1. on chain HFT:wintermute. 0x000002cba8dfb0a86a47a415592835e17fac080a (a great story here)
2. protocol : 0x0000000000b3F879cb30FE243b4Dfee438691c04 GST2

## how it work?
Technically,we use following features
1. create2
2. contract factory and upgradeable contract
3. on chain random

when you trade, you will try to *calculate* zero prefix, if you get one, you can claim a NFT. 
You can also burn an NFT to deploy an upgradeable contract and get its ownership.

