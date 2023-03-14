import { CurrencyAmount, Price, Token } from '../../core-sdk/src/entities'
import { ChainId } from '../../core-sdk/src/enums'

import { LimitOrder } from '../src'

async function main() {
    const addressConversionPool = "";
    const tokenA = new Token(ChainId.KOVAN, '0x6B175474E89094C44Da98b954EedeAC495271d0F', 18, 'DAI')
    const tokenB = new Token(ChainId.KOVAN, 'addressConversionPool', 18, 'PTK')

    const amountIn = CurrencyAmount.fromRawAmount(tokenA, '9000000000000000000')
    const amountOut = CurrencyAmount.fromRawAmount(tokenB, '8000000000000000000')
    const stopPrice = '100000000000000000'

    const limitOrder = new LimitOrder(
      '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
      amountIn,
      amountOut,
      '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      '0',
      '478384250',
      stopPrice,
      '0x0165878A594ca255338adfa4d48449f69242Eb8F',
      '0x00000000000000000000000000000000000000000000000000000000000000'
    )

    const bobo = '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a'
    limitOrder.signdOrderWithPrivatekey(ChainId.ETHEREUM, bobo)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
console.error(error);
process.exitCode = 1;
});


