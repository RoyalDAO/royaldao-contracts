# <img src="https://github.com/RoyalDAO/royaldao-contracts/blob/RELEASE/assets/images/RoyalDAO_Logo.png" alt="RoyalDao" height="80px">

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://royaldao.gitbook.io/royaldao-contracts/)
[![NPM Package](https://img.shields.io/npm/v/@royaldao/contracts.svg)](https://www.npmjs.org/package/@royaldao/contracts)

**A library for smart contract development of Complex NFT Based DAOs.

 * Implementations of new standards like [ERC721SenatorVotes](https://github.com/RoyalDAO/royaldao-contracts/blob/RELEASE/contracts/Token/ERC721/extensions/ERC721SenatorVotes.sol), [Senate](https://github.com/RoyalDAO/royaldao-contracts/blob/RELEASE/contracts/Governance/Senate.sol) and [Chancelor](https://github.com/RoyalDAO/royaldao-contracts/blob/RELEASE/contracts/Governance/Chancelor.sol).
 * Built upon [Openzeppelin's](https://www.openzeppelin.com/contracts) well known and tested Governance Libraries. Cannot say enough about how Openzeppelins libraries helped in my learning growth and how thankfull i am for them.
 * Stantard [ERC721SenatorVotes](https://github.com/RoyalDAO/royaldao-contracts/blob/RELEASE/contracts/Token/ERC721/extensions/ERC721SenatorVotes.sol) fully compatible with [ERC721](https://docs.openzeppelin.com/contracts/4.x/erc721) standard from [Openzeppelin](https://www.openzeppelin.com/contracts).
 * Built under [MIT](https://github.com/RoyalDAO/royaldao-contracts/blob/RELEASE/LICENSE) License. Use it, build upon it and help make it better!!!.

:mage: **Not sure how to get started?** Check out our usage [Examples](https://github.com/RoyalDAO/examples).

## Overview

### Who Am I?

I am [Vin Rodrigues](https://github.com/rodriguesmvinicius), Co-founder of [QueenEDAO](https://queene.wtf/), along with other 3 people (see more at [QueenE Repo](https://github.com/rodriguesmvinicius/QueenE_Contracts/blob/HEAD/README.md)), and the creator and, currently, only maintainer of RoyalDao Libraries.

[QueenEDAO](https://queene.wtf/) was an innovative project inspired by [NounsDAO](https://nouns.wtf/) and using [Openzeppelin](https://www.openzeppelin.com/) Governance Contracts.

The innovation in the project falls into the fact that the collection is tied to real world events and can end at an unknown moment.
In this specific case, the death of Queen Elizabeth, who inspired the fictional Character QueenE.

So, we knew from the beginning that we would need to find a solution to keep the DAO running and Growing after the event, that came sooner than any of us imagined.

With this background, I envisioned the Senate pattern. Based in the Governor pattern, from [Openzeppelin](https://www.openzeppelin.com/), the Senate allows multiple tokens (at this point, only ERC721) to participate into one single DAO. So, no matter the project you have tokens from, if it is a member of the Senate, you can propose and vote in the same DAO.

The basic pattern is usable in beta and documentation is being done. You can see usage examples [here](https://github.com/RoyalDAO/examples).

### Installation

```console
$ npm install @royaldao/contracts
```
Or using Yarn
```console
$ yarn add @royaldao/contracts
```

### Usage

Once installed, you can use the contracts in the library by importing them:

```solidity
pragma solidity ^0.8.0;

import "@royaldao/contracts/Governance/Chancellor.sol";

contract RepublicChancellor is
    Chancellor,
    ChancellorCompatibilityBravo,
    ChancellorSenateControl,
    ChancellorTimelockControl
{
    constructor(TimelockController _timelock, Senate _senate)
        Chancellor("RepublicChancelor")
        ChancellorSenateControl(_senate)
        ChancellorTimelockControl(_timelock)
    {}
}
```

If you're new to smart contract development, i strongly recomend all the content made by [Sir Patrick Collins](https://www.youtube.com/c/PatrickCollins), but specially his [36h Course](https://www.youtube.com/watch?v=gyMwXuJrbJQ)...i swear it's woth it!

## Learn More

I am currently building the base docs of the library usage. Should be done soon, depending on how much i need to sleep or rest (it has been a while).
But you can learn a lot by the [examples repo](https://github.com/RoyalDAO/examples).

Will update with documentation links when its done!

I urge you to take a look at [OpenZeppelins Knowledge base](https://docs.openzeppelin.com/)! It will help a lot in Smart Contracts Development learning path.

## Security

This project is maintained by [me mostly](https://github.com/rodriguesmvinicius), and developed following my questionable standard for code quality and security. So ,PLEASE, use common sense when doing anything that deals with real money! I take no responsibility for your implementation decisions and any security problems you might experience.

As soon i can leverage some funds from sponsorship (you can sponsor me through [Github Sponsor](https://github.com/sponsors/rodriguesmvinicius?o=esb) and [BuyMeACoffee](https://www.buymeacoffee.com/vinrodrigues)) i intend to audit everything, but 'till there, if you find any vulnerability, please contract us through security e-mail [sec.royaldao@gmail.com](mailto:sec.royaldao@gmail.com).

## Contribute

I will document the contributing process soon, but in the meanwhile you can email me at [royal dao.contracts@gmail.com](mailto:royal dao.contracts@gmail.com). Lets build!

## License

RoyalDao's Contracts is released under the [MIT License](LICENSE).
