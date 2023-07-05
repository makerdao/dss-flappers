certora-flapper-univ2 :; CERTORA_OLD_API=1 PATH=~/.solc-select/artifacts/solc-0.8.16:~/.solc-select/artifacts/solc-0.5.12:~/.solc-select/artifacts/solc-0.5.16:~/.solc-select/artifacts/solc-0.4.18:~/.solc-select/artifacts:${PATH} certoraRun --solc_map FlapperUniV2=solc-0.8.16,Vat=solc-0.5.12,DaiJoin=solc-0.5.12,Dai=solc-0.5.12,DSToken=solc-0.4.18,SpotterMock=solc-0.8.16,PipMock=solc-0.8.16,UniswapV2Pair=solc-0.5.16,UniswapV2FactoryMock=solc-0.8.16 --optimize_map FlapperUniV2=200,Vat=0,DaiJoin=0,Dai=0,DSToken=200,SpotterMock=0,PipMock=0,UniswapV2Pair=999999,UniswapV2FactoryMock=0 --rule_sanity basic src/FlapperUniV2.sol certora/dss/Vat.sol certora/dss/DaiJoin.sol certora/dss/Dai.sol certora/dss/DSToken.sol certora/dss/SpotterMock.sol certora/dss/PipMock.sol certora/univ2/UniswapV2Pair.sol certora/univ2/UniswapV2FactoryMock.sol certora/univ2/UniswapV2FactoryMock.sol --link FlapperUniV2:vat=Vat FlapperUniV2:daiJoin=DaiJoin FlapperUniV2:dai=Dai FlapperUniV2:gem=DSToken FlapperUniV2:spotter=SpotterMock FlapperUniV2:pip=PipMock FlapperUniV2:pair=UniswapV2Pair DaiJoin:vat=Vat DaiJoin:dai=Dai UniswapV2Pair:token0=Dai UniswapV2Pair:token1=DSToken UniswapV2Pair:factory=UniswapV2FactoryMock --verify FlapperUniV2:certora/FlapperUniV2.spec --settings '-splitParallel=true,-depth=15,-dontStopAtFirstSplitTimeout=true,-numOfParallelSplits=5,-splitParallelTimelimit=7000' --smt_timeout 3600 --optimistic_loop$(if $(short), --short_output,)$(if $(rule), --rule $(rule),)$(if $(multi), --multi_assert_check,)
