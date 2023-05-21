# Travel Parametric Insurance

## Background Information

Holidays for salariat are rare and precious.

Imagine a Beijing family preparing for a seven-days trip to Sanya three months in advance.
They spent a lot of money on flights and hotels booking.
Approaching departures are told flights cancelled due to bad weather.
Or their flight is normal,but the weather is too hot or rainy to affect the travel experience.
In these cases they can buy travel insurance to hedge their risks.

Others don't think it's necessary to buy insurance against rare events.
They think selling insurance is a good business.
Okay they can play the role of insurance companies,inject capital into the contract,making a profit if the preset rare events does not occur.

This is a decentralized insurance product,no insurance companies participate.

## Project Architecture

Forked from chainlink
[functions-insurance](https://github.com/smartcontractkit/functions-insurance)

Modify [ParametricInsurance.sol](https://github.com/Royhoo/travel-parametric-insurance/tree/main/contracts) to add the function of buying insurance,injecting capital,and withdrawing funds at the end of the policy.

Of course, this is a simple example, and many features are not perfect.
If anyone finds the idea worthwhile, we can work together on it as a long-term project.

## Steps to run this sample

Complete the steps of [functions-insurance](https://github.com/smartcontractkit/functions-insurance) first.

### test
`npx hardhat functions-deploy-client-local` test smart contract whitout chainlink

`npx hardhat functions-simulate` test chainlink function

### deploy
`npx hardhat functions-deploy-client --network mumbai --verify true`

### create subid
`npx hardhat functions-sub-create --network mumbai --amount 1 --contract YOUR_CONTRACT_ADDRESS`

### functionsrequest
`npx hardhat functions-request --network mumbai --contract YOUR_CONTRACT_ADDRESS --subid YOUR_SUBID --gaslimit 300000`