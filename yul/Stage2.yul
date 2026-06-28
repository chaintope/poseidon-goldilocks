object "Stage2" {
  code { datacopy(0, dataoffset("runtime"), datasize("runtime")) return(0, datasize("runtime")) }
  object "runtime" {
    code {
      // No function-selector dispatch: this object is delegatecall'd from exactly one site
      // (PoseidonGoldilocks.permute -> PGStage2.run) with a fixed calldata layout. The caller
      // still ABI-encodes the run(uint256,uint256,uint256) selector (4 bytes), so the three
      // state words stay at calldata offsets 4/36/68; we simply don't verify the selector,
      // dropping ~28 gas of CALLDATALOAD/SHR/EQ/ISZERO/JUMPI per permute. Bit-exact (the
      // computation is unchanged); differential fuzz + plonky2 vector still pass.
      prAll()
      { // full round 6
      let p := 0xFFFFFFFF00000001
      let v0 := add(mload(0x00), 16645869274577729720)
      { let x2 := mul(v0,v0) v0 := mulmod(mul(x2,v0), mulmod(x2,x2,p), p) }
      let v1 := add(mload(0x20), 8039205965509554440)
      { let x2 := mul(v1,v1) v1 := mulmod(mul(x2,v1), mulmod(x2,x2,p), p) }
      let v2 := add(mload(0x40), 4788586935019371140)
      { let x2 := mul(v2,v2) v2 := mulmod(mul(x2,v2), mulmod(x2,x2,p), p) }
      let v3 := add(mload(0x60), 15129007200040077746)
      { let x2 := mul(v3,v3) v3 := mulmod(mul(x2,v3), mulmod(x2,x2,p), p) }
      let v4 := add(mload(0x80), 2055561615223771341)
      { let x2 := mul(v4,v4) v4 := mulmod(mul(x2,v4), mulmod(x2,x2,p), p) }
      let v5 := add(mload(0xa0), 4149731103701412892)
      { let x2 := mul(v5,v5) v5 := mulmod(mul(x2,v5), mulmod(x2,x2,p), p) }
      let v6 := add(mload(0xc0), 10268130195734144189)
      { let x2 := mul(v6,v6) v6 := mulmod(mul(x2,v6), mulmod(x2,x2,p), p) }
      let v7 := add(mload(0xe0), 13406631635880074708)
      { let x2 := mul(v7,v7) v7 := mulmod(mul(x2,v7), mulmod(x2,x2,p), p) }
      let v8 := add(mload(0x100), 11429218277824986203)
      { let x2 := mul(v8,v8) v8 := mulmod(mul(x2,v8), mulmod(x2,x2,p), p) }
      let v9 := add(mload(0x120), 15773968030812198565)
      { let x2 := mul(v9,v9) v9 := mulmod(mul(x2,v9), mulmod(x2,x2,p), p) }
      let v10 := add(mload(0x140), 16050275277550506872)
      { let x2 := mul(v10,v10) v10 := mulmod(mul(x2,v10), mulmod(x2,x2,p), p) }
      let v11 := add(mload(0x160), 11858586752031736643)
      { let x2 := mul(v11,v11) v11 := mulmod(mul(x2,v11), mulmod(x2,x2,p), p) }
                  mstore(0x0, add(add(add(add(add(add(add(add(add(add(mul(v0, 25), mul(v1, 15)), mul(v2, 41)), shl(4, v3)), shl(1, v4)), mul(v5, 28)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(add(v6, v7), 13)))
            mstore(0x20, add(add(add(add(add(add(add(add(add(add(mul(v0, 20), mul(v1, 17)), mul(v2, 15)), mul(v3, 41)), shl(4, v4)), shl(1, v5)), mul(v6, 28)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(add(v7, v8), 13)))
            mstore(0x40, add(add(add(add(add(add(add(add(add(add(mul(v0, 34), mul(v1, 20)), mul(v2, 17)), mul(v3, 15)), mul(v4, 41)), shl(4, v5)), shl(1, v6)), mul(v7, 28)), mul(v10, 39)), mul(v11, 18)), mul(add(v8, v9), 13)))
            mstore(0x60, add(add(add(add(add(add(add(add(add(add(mul(v0, 18), mul(v1, 34)), mul(v2, 20)), mul(v3, 17)), mul(v4, 15)), mul(v5, 41)), shl(4, v6)), shl(1, v7)), mul(v8, 28)), mul(v11, 39)), mul(add(v9, v10), 13)))
            mstore(0x80, add(add(add(add(add(add(add(add(add(add(mul(v0, 39), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), mul(v4, 17)), mul(v5, 15)), mul(v6, 41)), shl(4, v7)), shl(1, v8)), mul(v9, 28)), mul(add(v10, v11), 13)))
            mstore(0xa0, add(add(add(add(add(add(add(add(add(add(mul(v1, 39), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), mul(v5, 17)), mul(v6, 15)), mul(v7, 41)), shl(4, v8)), shl(1, v9)), mul(v10, 28)), mul(add(v11, v0), 13)))
            mstore(0xc0, add(add(add(add(add(add(add(add(add(add(mul(v2, 39), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), mul(v6, 17)), mul(v7, 15)), mul(v8, 41)), shl(4, v9)), shl(1, v10)), mul(v11, 28)), mul(add(v0, v1), 13)))
            mstore(0xe0, add(add(add(add(add(add(add(add(add(add(mul(v0, 28), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), mul(v7, 17)), mul(v8, 15)), mul(v9, 41)), shl(4, v10)), shl(1, v11)), mul(add(v1, v2), 13)))
            mstore(0x100, add(add(add(add(add(add(add(add(add(add(shl(1, v0), mul(v1, 28)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), mul(v8, 17)), mul(v9, 15)), mul(v10, 41)), shl(4, v11)), mul(add(v2, v3), 13)))
            mstore(0x120, add(add(add(add(add(add(add(add(add(add(shl(4, v0), shl(1, v1)), mul(v2, 28)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), mul(v9, 17)), mul(v10, 15)), mul(v11, 41)), mul(add(v3, v4), 13)))
            mstore(0x140, add(add(add(add(add(add(add(add(add(add(mul(v0, 41), shl(4, v1)), shl(1, v2)), mul(v3, 28)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), mul(v10, 17)), mul(v11, 15)), mul(add(v4, v5), 13)))
            mstore(0x160, add(add(add(add(add(add(add(add(add(add(mul(v0, 15), mul(v1, 41)), shl(4, v2)), shl(1, v3)), mul(v4, 28)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), mul(v11, 17)), mul(add(v5, v6), 13)))
      }
      { // full round 7
      let p := 0xFFFFFFFF00000001
      let v0 := add(mload(0x00), 8927746344866569756)
      { let x2 := mul(v0,v0) v0 := mulmod(mul(x2,v0), mulmod(x2,x2,p), p) }
      let v1 := add(mload(0x20), 11802068403177695792)
      { let x2 := mul(v1,v1) v1 := mulmod(mul(x2,v1), mulmod(x2,x2,p), p) }
      let v2 := add(mload(0x40), 157833420806751556)
      { let x2 := mul(v2,v2) v2 := mulmod(mul(x2,v2), mulmod(x2,x2,p), p) }
      let v3 := add(mload(0x60), 4698875910749767878)
      { let x2 := mul(v3,v3) v3 := mulmod(mul(x2,v3), mulmod(x2,x2,p), p) }
      let v4 := add(mload(0x80), 1616722774788291698)
      { let x2 := mul(v4,v4) v4 := mulmod(mul(x2,v4), mulmod(x2,x2,p), p) }
      let v5 := add(mload(0xa0), 3990951895163748090)
      { let x2 := mul(v5,v5) v5 := mulmod(mul(x2,v5), mulmod(x2,x2,p), p) }
      let v6 := add(mload(0xc0), 16758609224720795472)
      { let x2 := mul(v6,v6) v6 := mulmod(mul(x2,v6), mulmod(x2,x2,p), p) }
      let v7 := add(mload(0xe0), 3045571693290741477)
      { let x2 := mul(v7,v7) v7 := mulmod(mul(x2,v7), mulmod(x2,x2,p), p) }
      let v8 := add(mload(0x100), 9281634245289836419)
      { let x2 := mul(v8,v8) v8 := mulmod(mul(x2,v8), mulmod(x2,x2,p), p) }
      let v9 := add(mload(0x120), 13517688176723875370)
      { let x2 := mul(v9,v9) v9 := mulmod(mul(x2,v9), mulmod(x2,x2,p), p) }
      let v10 := add(mload(0x140), 7961395585333219380)
      { let x2 := mul(v10,v10) v10 := mulmod(mul(x2,v10), mulmod(x2,x2,p), p) }
      let v11 := add(mload(0x160), 1606574359105691080)
      { let x2 := mul(v11,v11) v11 := mulmod(mul(x2,v11), mulmod(x2,x2,p), p) }
                  mstore(0x0, add(add(add(add(add(add(add(add(add(add(mul(v0, 25), mul(v1, 15)), mul(v2, 41)), shl(4, v3)), shl(1, v4)), mul(v5, 28)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(add(v6, v7), 13)))
            mstore(0x20, add(add(add(add(add(add(add(add(add(add(mul(v0, 20), mul(v1, 17)), mul(v2, 15)), mul(v3, 41)), shl(4, v4)), shl(1, v5)), mul(v6, 28)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(add(v7, v8), 13)))
            mstore(0x40, add(add(add(add(add(add(add(add(add(add(mul(v0, 34), mul(v1, 20)), mul(v2, 17)), mul(v3, 15)), mul(v4, 41)), shl(4, v5)), shl(1, v6)), mul(v7, 28)), mul(v10, 39)), mul(v11, 18)), mul(add(v8, v9), 13)))
            mstore(0x60, add(add(add(add(add(add(add(add(add(add(mul(v0, 18), mul(v1, 34)), mul(v2, 20)), mul(v3, 17)), mul(v4, 15)), mul(v5, 41)), shl(4, v6)), shl(1, v7)), mul(v8, 28)), mul(v11, 39)), mul(add(v9, v10), 13)))
            mstore(0x80, add(add(add(add(add(add(add(add(add(add(mul(v0, 39), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), mul(v4, 17)), mul(v5, 15)), mul(v6, 41)), shl(4, v7)), shl(1, v8)), mul(v9, 28)), mul(add(v10, v11), 13)))
            mstore(0xa0, add(add(add(add(add(add(add(add(add(add(mul(v1, 39), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), mul(v5, 17)), mul(v6, 15)), mul(v7, 41)), shl(4, v8)), shl(1, v9)), mul(v10, 28)), mul(add(v11, v0), 13)))
            mstore(0xc0, add(add(add(add(add(add(add(add(add(add(mul(v2, 39), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), mul(v6, 17)), mul(v7, 15)), mul(v8, 41)), shl(4, v9)), shl(1, v10)), mul(v11, 28)), mul(add(v0, v1), 13)))
            mstore(0xe0, add(add(add(add(add(add(add(add(add(add(mul(v0, 28), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), mul(v7, 17)), mul(v8, 15)), mul(v9, 41)), shl(4, v10)), shl(1, v11)), mul(add(v1, v2), 13)))
            mstore(0x100, add(add(add(add(add(add(add(add(add(add(shl(1, v0), mul(v1, 28)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), mul(v8, 17)), mul(v9, 15)), mul(v10, 41)), shl(4, v11)), mul(add(v2, v3), 13)))
            mstore(0x120, add(add(add(add(add(add(add(add(add(add(shl(4, v0), shl(1, v1)), mul(v2, 28)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), mul(v9, 17)), mul(v10, 15)), mul(v11, 41)), mul(add(v3, v4), 13)))
            mstore(0x140, add(add(add(add(add(add(add(add(add(add(mul(v0, 41), shl(4, v1)), shl(1, v2)), mul(v3, 28)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), mul(v10, 17)), mul(v11, 15)), mul(add(v4, v5), 13)))
            mstore(0x160, add(add(add(add(add(add(add(add(add(add(mul(v0, 15), mul(v1, 41)), shl(4, v2)), shl(1, v3)), mul(v4, 28)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), mul(v11, 17)), mul(add(v5, v6), 13)))
      }
      { // full round 8
      let p := 0xFFFFFFFF00000001
      let v0 := add(mload(0x00), 17564372683613562171)
      { let x2 := mul(v0,v0) v0 := mulmod(mul(x2,v0), mulmod(x2,x2,p), p) }
      let v1 := add(mload(0x20), 4664015225343144418)
      { let x2 := mul(v1,v1) v1 := mulmod(mul(x2,v1), mulmod(x2,x2,p), p) }
      let v2 := add(mload(0x40), 6133721340680280128)
      { let x2 := mul(v2,v2) v2 := mulmod(mul(x2,v2), mulmod(x2,x2,p), p) }
      let v3 := add(mload(0x60), 2667022304383014929)
      { let x2 := mul(v3,v3) v3 := mulmod(mul(x2,v3), mulmod(x2,x2,p), p) }
      let v4 := add(mload(0x80), 12316557761857340230)
      { let x2 := mul(v4,v4) v4 := mulmod(mul(x2,v4), mulmod(x2,x2,p), p) }
      let v5 := add(mload(0xa0), 10375614850625292317)
      { let x2 := mul(v5,v5) v5 := mulmod(mul(x2,v5), mulmod(x2,x2,p), p) }
      let v6 := add(mload(0xc0), 8141542666379135068)
      { let x2 := mul(v6,v6) v6 := mulmod(mul(x2,v6), mulmod(x2,x2,p), p) }
      let v7 := add(mload(0xe0), 9185476451083834432)
      { let x2 := mul(v7,v7) v7 := mulmod(mul(x2,v7), mulmod(x2,x2,p), p) }
      let v8 := add(mload(0x100), 4991072365274649547)
      { let x2 := mul(v8,v8) v8 := mulmod(mul(x2,v8), mulmod(x2,x2,p), p) }
      let v9 := add(mload(0x120), 17398204971778820365)
      { let x2 := mul(v9,v9) v9 := mulmod(mul(x2,v9), mulmod(x2,x2,p), p) }
      let v10 := add(mload(0x140), 16127888338958422584)
      { let x2 := mul(v10,v10) v10 := mulmod(mul(x2,v10), mulmod(x2,x2,p), p) }
      let v11 := add(mload(0x160), 13586792051317758204)
      { let x2 := mul(v11,v11) v11 := mulmod(mul(x2,v11), mulmod(x2,x2,p), p) }
      mds_pack(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11)
      }
      return(0, 96)
      function prAll() {
        let p := 0xFFFFFFFF00000001
        let M := 0xFFFFFFFFFFFFFFFF
        let w0 := calldataload(4)
        let w1 := calldataload(36)
        let w2 := calldataload(68)
        let v0 := and(w0, M)
        let v1 := and(shr(64, w0), M)
        let v2 := and(shr(128, w0), M)
        let v3 := shr(192, w0)
        let v4 := and(w1, M)
        let v5 := and(shr(64, w1), M)
        let v6 := and(shr(128, w1), M)
        let v7 := shr(192, w1)
        let v8 := and(w2, M)
        let v9 := and(shr(64, w2), M)
        let v10 := and(shr(128, w2), M)
        let v11 := shr(192, w2)
        { // partial round 11
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 8581622869689923244) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 1637471090675303584))
          v1 := add(v1, mul(s0, 9570691013274316785))
          d := add(d, mul(v2, 4375318637115686030))
          v2 := add(v2, mul(s0, 15613851939195720118))
          d := add(d, mul(v3, 12136810621975340177))
          v3 := add(v3, mul(s0, 3699802456427549428))
          d := add(d, mul(v4, 105995675382122926))
          v4 := add(v4, mul(s0, 14363933592354809237))
          d := add(d, mul(v5, 5987457663538146171))
          v5 := add(v5, mul(s0, 13863573127618181752))
          d := add(d, mul(v6, 15717760330284389791))
          v6 := add(v6, mul(s0, 11428524752427198786))
          d := add(d, mul(v7, 14670439359715404205))
          v7 := add(v7, mul(s0, 1512236798846210343))
          d := add(d, mul(v8, 5464349733274908045))
          v8 := add(v8, mul(s0, 15492557605200192531))
          d := add(d, mul(v9, 8636933789572244554))
          v9 := add(v9, mul(s0, 4471766256042329601))
          d := add(d, mul(v10, 9769580318971544573))
          v10 := add(v10, mul(s0, 12055723375080267479))
          d := add(d, mul(v11, 9102363839782539970))
          v11 := add(v11, mul(s0, 16720313860519281958))
          v0 := mod(d, p)
        }
        { // partial round 12
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 12649521141086658944) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 13571765139831017037))
          v1 := add(v1, mul(s0, 2561042796132833389))
          d := add(d, mul(v2, 818883284762741475))
          v2 := add(v2, mul(s0, 10464014529858294964))
          d := add(d, mul(v3, 11800681286871024320))
          v3 := add(v3, mul(s0, 14401165907148431066))
          d := add(d, mul(v4, 4228007315495729552))
          v4 := add(v4, mul(s0, 2413453332765052361))
          d := add(d, mul(v5, 9681067057645014410))
          v5 := add(v5, mul(s0, 14620959153325857181))
          d := add(d, mul(v6, 10160317193366865607))
          v6 := add(v6, mul(s0, 16368665425253279930))
          d := add(d, mul(v7, 7974952474492003064))
          v7 := add(v7, mul(s0, 8913590094823920770))
          d := add(d, mul(v8, 311630947502800583))
          v8 := add(v8, mul(s0, 4357291993877750483))
          d := add(d, mul(v9, 16977972518193735910))
          v9 := add(v9, mul(s0, 18315259589408480902))
          d := add(d, mul(v10, 615971843838204966))
          v10 := add(v10, mul(s0, 7040130461852977952))
          d := add(d, mul(v11, 17678304266887460895))
          v11 := add(v11, mul(s0, 16913088801316332783))
          v0 := mod(d, p)
        }
        { // partial round 13
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 13316298133620363637) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 12163901532241384359))
          v1 := add(v1, mul(s0, 15483762529902925134))
          d := add(d, mul(v2, 5826724299253731684))
          v2 := add(v2, mul(s0, 17034733783218795199))
          d := add(d, mul(v3, 17423022063725297026))
          v3 := add(v3, mul(s0, 18136305076967260316))
          d := add(d, mul(v4, 18082834829462388363))
          v4 := add(v4, mul(s0, 15896912869485945382))
          d := add(d, mul(v5, 10626880031407069622))
          v5 := add(v5, mul(s0, 475392759889361288))
          d := add(d, mul(v6, 1952478840402025861))
          v6 := add(v6, mul(s0, 1823867867187688822))
          d := add(d, mul(v7, 9036125440908740987))
          v7 := add(v7, mul(s0, 8817375076608676110))
          d := add(d, mul(v8, 1042941967034175129))
          v8 := add(v8, mul(s0, 8857453095514132937))
          d := add(d, mul(v9, 13710136024884221835))
          v9 := add(v9, mul(s0, 17995601973761478278))
          d := add(d, mul(v10, 3995229588248274477))
          v10 := add(v10, mul(s0, 18042919419769033432))
          d := add(d, mul(v11, 11993482789377134210))
          v11 := add(v11, mul(s0, 17356815683605755783))
          v0 := mod(d, p)
        }
        { // partial round 14
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 10757436128916982213) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 12697151891341221277))
          v1 := add(v1, mul(s0, 853567178463642200))
          d := add(d, mul(v2, 13408757364964309332))
          v2 := add(v2, mul(s0, 781481719657018312))
          d := add(d, mul(v3, 14636730641620356003))
          v3 := add(v3, mul(s0, 864881582238738022))
          d := add(d, mul(v4, 2917199062768996165))
          v4 := add(v4, mul(s0, 776585443674182031))
          d := add(d, mul(v5, 11768157571822112934))
          v5 := add(v5, mul(s0, 868289454518583667))
          d := add(d, mul(v6, 15407074889369976729))
          v6 := add(v6, mul(s0, 873991676947315745))
          d := add(d, mul(v7, 3320959039775894817))
          v7 := add(v7, mul(s0, 825112067366636056))
          d := add(d, mul(v8, 16277817307991958146))
          v8 := add(v8, mul(s0, 904067466148006484))
          d := add(d, mul(v9, 7362033657200491320))
          v9 := add(v9, mul(s0, 864277137123579536))
          d := add(d, mul(v10, 9990801137147894185))
          v10 := add(v10, mul(s0, 785755357347442049))
          d := add(d, mul(v11, 14676096006818979429))
          v11 := add(v11, mul(s0, 861609966041484849))
          v0 := mod(d, p)
        }
        { // partial round 15
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 16047932205709436219) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 17204396082766500862))
          v1 := add(v1, mul(s0, 3644417860664408))
          d := add(d, mul(v2, 14458712079049372979))
          v2 := add(v2, mul(s0, 3335591043919560))
          d := add(d, mul(v3, 17287567422807715153))
          v3 := add(v3, mul(s0, 3691922388548390))
          d := add(d, mul(v4, 13337198174858709409))
          v4 := add(v4, mul(s0, 3315658209334511))
          d := add(d, mul(v5, 7624105753184612060))
          v5 := add(v5, mul(s0, 3706319247139923))
          d := add(d, mul(v6, 17074874386857691157))
          v6 := add(v6, mul(s0, 3730913850857153))
          d := add(d, mul(v7, 2909991590741947335))
          v7 := add(v7, mul(s0, 3522914930316824))
          d := add(d, mul(v8, 14770785872198722410))
          v8 := add(v8, mul(s0, 3859199185371348))
          d := add(d, mul(v9, 17719065353010659993))
          v9 := add(v9, mul(s0, 3689373458353040))
          d := add(d, mul(v10, 14898159957685527729))
          v10 := add(v10, mul(s0, 3354664939836449))
          d := add(d, mul(v11, 12135206555549668255))
          v11 := add(v11, mul(s0, 3677753419960785))
          v0 := mod(d, p)
        }
        { // partial round 16
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 17301616663694082334) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 15626888021543284549))
          v1 := add(v1, mul(s0, 15551163980504))
          d := add(d, mul(v2, 12464927884746769804))
          v2 := add(v2, mul(s0, 14240130616264))
          d := add(d, mul(v3, 1471467344747928256))
          v3 := add(v3, mul(s0, 15771333781862))
          d := add(d, mul(v4, 11413582290460358915))
          v4 := add(v4, mul(s0, 14149230256207))
          d := add(d, mul(v5, 9282109700482247280))
          v5 := add(v5, mul(s0, 15820017123763))
          d := add(d, mul(v6, 17976144115670124039))
          v6 := add(v6, mul(s0, 15936503968609))
          d := add(d, mul(v7, 16456828278798000758))
          v7 := add(v7, mul(s0, 15031975505304))
          d := add(d, mul(v8, 1008181782916845414))
          v8 := add(v8, mul(s0, 16471548413268))
          d := add(d, mul(v9, 17610348098917415827))
          v9 := add(v9, mul(s0, 15760188783376))
          d := add(d, mul(v10, 204173067177706516))
          v10 := add(v10, mul(s0, 14317015483073))
          d := add(d, mul(v11, 15964669298669259045))
          v11 := add(v11, mul(s0, 15696239618801))
          v0 := mod(d, p)
        }
        { // partial round 17
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 11667617191967502297) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 13932676290161493411))
          v1 := add(v1, mul(s0, 66326084760))
          d := add(d, mul(v2, 14699132604785301972))
          v2 := add(v2, mul(s0, 60935297352))
          d := add(d, mul(v3, 3744215611852980773))
          v3 := add(v3, mul(s0, 67215299046))
          d := add(d, mul(v4, 2709414263278899107))
          v4 := add(v4, mul(s0, 60348857903))
          d := add(d, mul(v5, 806263865491310800))
          v5 := add(v5, mul(s0, 67671686739))
          d := add(d, mul(v6, 7317365142041602481))
          v6 := add(v6, mul(s0, 67914356993))
          d := add(d, mul(v7, 16776386564962992796))
          v7 := add(v7, mul(s0, 64112320984))
          d := add(d, mul(v8, 11652640766067723448))
          v8 := add(v8, mul(s0, 70469953364))
          d := add(d, mul(v9, 1016370456237928832))
          v9 := add(v9, mul(s0, 67111186256))
          d := add(d, mul(v10, 961864172302955643))
          v10 := add(v10, mul(s0, 61118430945))
          d := add(d, mul(v11, 11539305592151691719))
          v11 := add(v11, mul(s0, 67182327505))
          v0 := mod(d, p)
        }
        { // partial round 18
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 9658934864843380542) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 5260886902259565990))
          v1 := add(v1, mul(s0, 286463800))
          d := add(d, mul(v2, 16171862215293778203))
          v2 := add(v2, mul(s0, 257349000))
          d := add(d, mul(v3, 771114262717812991))
          v3 := add(v3, mul(s0, 285544326))
          d := add(d, mul(v4, 10575516421403467499))
          v4 := add(v4, mul(s0, 260345679))
          d := add(d, mul(v5, 13137658605724015568))
          v5 := add(v5, mul(s0, 286599123))
          d := add(d, mul(v6, 4324696043571725046))
          v6 := add(v6, mul(s0, 289630625))
          d := add(d, mul(v7, 17177140657993423090))
          v7 := add(v7, mul(s0, 275722040))
          d := add(d, mul(v8, 11675287481120654357))
          v8 := add(v8, mul(s0, 300075668))
          d := add(d, mul(v9, 215782959819461329))
          v9 := add(v9, mul(s0, 285878768))
          d := add(d, mul(v10, 16817340479494209298))
          v10 := add(v10, mul(s0, 262796737))
          d := add(d, mul(v11, 2305466969888960689))
          v11 := add(v11, mul(s0, 284566993))
          v0 := mod(d, p)
        }
        { // partial round 19
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 3498090033303964622) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 9354449820649144563))
          v1 := add(v1, mul(s0, 1177368))
          d := add(d, mul(v2, 17638200638691477463))
          v2 := add(v2, mul(s0, 1095368))
          d := add(d, mul(v3, 17096907883840532417))
          v3 := add(v3, mul(s0, 1264278))
          d := add(d, mul(v4, 795566415402858691))
          v4 := add(v4, mul(s0, 1101695))
          d := add(d, mul(v5, 12763188014703795610))
          v5 := add(v5, mul(s0, 1199363))
          d := add(d, mul(v6, 2111548358776179736))
          v6 := add(v6, mul(s0, 1308833))
          d := add(d, mul(v7, 7338420082729848069))
          v7 := add(v7, mul(s0, 1145944))
          d := add(d, mul(v8, 11736253547470159946))
          v8 := add(v8, mul(s0, 1256596))
          d := add(d, mul(v9, 11882449274483722406))
          v9 := add(v9, mul(s0, 1265600))
          d := add(d, mul(v10, 13880779032198735515))
          v10 := add(v10, mul(s0, 1089681))
          d := add(d, mul(v11, 12012886003476663648))
          v11 := add(v11, mul(s0, 1214817))
          v0 := mod(d, p)
        }
        { // partial round 20
          let s0 { let x2 := mul(v0,v0) s0 := add(mulmod(mul(x2,v0), mulmod(x2,x2,p), p), 1930488375833774198) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 9561079619973624339))
          v1 := add(v1, mul(s0, 4864))
          d := add(d, mul(v2, 3427032003991111411))
          v2 := add(v2, mul(s0, 5968))
          d := add(d, mul(v3, 16026109245305520857))
          v3 := add(v3, mul(s0, 4430))
          d := add(d, mul(v4, 842178779993054962))
          v4 := add(v4, mul(s0, 4895))
          d := add(d, mul(v5, 6620069080479782436))
          v5 := add(v5, mul(s0, 5755))
          d := add(d, mul(v6, 520632651104976912))
          v6 := add(v6, mul(s0, 4977))
          d := add(d, mul(v7, 5977708219320356796))
          v7 := add(v7, mul(s0, 4656))
          d := add(d, mul(v8, 14677035874152442976))
          v8 := add(v8, mul(s0, 6188))
          d := add(d, mul(v9, 12438555763140714832))
          v9 := add(v9, mul(s0, 4968))
          d := add(d, mul(v10, 10308634069667372976))
          v10 := add(v10, mul(s0, 3889))
          d := add(d, mul(v11, 1889137300031443018))
          v11 := add(v11, mul(s0, 5577))
          v0 := mod(d, p)
        }
        { // partial round 21
          let s0 { let x2 := mul(v0,v0) s0 := mulmod(mul(x2,v0), mulmod(x2,x2,p), p) }
          let d := mul(s0, 25)
          d := add(d, mul(v1, 4233023069765094533))
          v1 := add(v1, mul(s0, 20))
          d := add(d, mul(v2, 11320301090717319475))
          v2 := add(v2, mul(s0, 34))
          d := add(d, mul(v3, 529847152638273925))
          v3 := add(v3, mul(s0, 18))
          d := add(d, mul(v4, 11362416581384070759))
          v4 := add(v4, mul(s0, 39))
          d := add(d, mul(v5, 3913471784331119128))
          v5 := add(v5, mul(s0, 13))
          d := add(d, mul(v6, 5817936720856651185))
          v6 := add(v6, mul(s0, 13))
          d := add(d, mul(v7, 17448019282603275260))
          v7 := add(v7, mul(s0, 28))
          d := add(d, mul(v8, 3425091249974323865))
          v8 := add(v8, shl(1, s0))
          d := add(d, mul(v9, 13157846471433414730))
          v9 := add(v9, shl(4, s0))
          d := add(d, mul(v10, 673370378535461536))
          v10 := add(v10, mul(s0, 41))
          d := add(d, mul(v11, 846766219905577371))
          v11 := add(v11, mul(s0, 15))
          v0 := mod(d, p)
        }
        // fold full round 5 (add round const + S-box) directly on registers, S-box inlined
        { let t := add(v0, 5142217010456550622) let x2 := mul(t,t) v0 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v1, 1775580461722730120) let x2 := mulmod(t,t,p) v1 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v2, 161694268822794344) let x2 := mulmod(t,t,p) v2 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v3, 1518963253808031703) let x2 := mulmod(t,t,p) v3 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v4, 16475258091652710137) let x2 := mulmod(t,t,p) v4 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v5, 119575899007375159) let x2 := mulmod(t,t,p) v5 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v6, 1275863735937973999) let x2 := mulmod(t,t,p) v6 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v7, 16539412514520642374) let x2 := mulmod(t,t,p) v7 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v8, 2303365191438051950) let x2 := mulmod(t,t,p) v8 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v9, 6435126839960916075) let x2 := mulmod(t,t,p) v9 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v10, 17794599201026020053) let x2 := mulmod(t,t,p) v10 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
        { let t := add(v11, 13847097589277840330) let x2 := mulmod(t,t,p) v11 := mulmod(mul(x2,t), mulmod(x2,x2,p), p) }
                    mstore(0x0, add(add(add(add(add(add(add(add(add(add(mul(v0, 25), mul(v1, 15)), mul(v2, 41)), shl(4, v3)), shl(1, v4)), mul(v5, 28)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(add(v6, v7), 13)))
            mstore(0x20, add(add(add(add(add(add(add(add(add(add(mul(v0, 20), mul(v1, 17)), mul(v2, 15)), mul(v3, 41)), shl(4, v4)), shl(1, v5)), mul(v6, 28)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(add(v7, v8), 13)))
            mstore(0x40, add(add(add(add(add(add(add(add(add(add(mul(v0, 34), mul(v1, 20)), mul(v2, 17)), mul(v3, 15)), mul(v4, 41)), shl(4, v5)), shl(1, v6)), mul(v7, 28)), mul(v10, 39)), mul(v11, 18)), mul(add(v8, v9), 13)))
            mstore(0x60, add(add(add(add(add(add(add(add(add(add(mul(v0, 18), mul(v1, 34)), mul(v2, 20)), mul(v3, 17)), mul(v4, 15)), mul(v5, 41)), shl(4, v6)), shl(1, v7)), mul(v8, 28)), mul(v11, 39)), mul(add(v9, v10), 13)))
            mstore(0x80, add(add(add(add(add(add(add(add(add(add(mul(v0, 39), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), mul(v4, 17)), mul(v5, 15)), mul(v6, 41)), shl(4, v7)), shl(1, v8)), mul(v9, 28)), mul(add(v10, v11), 13)))
            mstore(0xa0, add(add(add(add(add(add(add(add(add(add(mul(v1, 39), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), mul(v5, 17)), mul(v6, 15)), mul(v7, 41)), shl(4, v8)), shl(1, v9)), mul(v10, 28)), mul(add(v11, v0), 13)))
            mstore(0xc0, add(add(add(add(add(add(add(add(add(add(mul(v2, 39), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), mul(v6, 17)), mul(v7, 15)), mul(v8, 41)), shl(4, v9)), shl(1, v10)), mul(v11, 28)), mul(add(v0, v1), 13)))
            mstore(0xe0, add(add(add(add(add(add(add(add(add(add(mul(v0, 28), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), mul(v7, 17)), mul(v8, 15)), mul(v9, 41)), shl(4, v10)), shl(1, v11)), mul(add(v1, v2), 13)))
            mstore(0x100, add(add(add(add(add(add(add(add(add(add(shl(1, v0), mul(v1, 28)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), mul(v8, 17)), mul(v9, 15)), mul(v10, 41)), shl(4, v11)), mul(add(v2, v3), 13)))
            mstore(0x120, add(add(add(add(add(add(add(add(add(add(shl(4, v0), shl(1, v1)), mul(v2, 28)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), mul(v9, 17)), mul(v10, 15)), mul(v11, 41)), mul(add(v3, v4), 13)))
            mstore(0x140, add(add(add(add(add(add(add(add(add(add(mul(v0, 41), shl(4, v1)), shl(1, v2)), mul(v3, 28)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), mul(v10, 17)), mul(v11, 15)), mul(add(v4, v5), 13)))
            mstore(0x160, add(add(add(add(add(add(add(add(add(add(mul(v0, 15), mul(v1, 41)), shl(4, v2)), shl(1, v3)), mul(v4, 28)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), mul(v11, 17)), mul(add(v5, v6), 13)))
      }
      function mds_pack(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11) {
            let p := 0xFFFFFFFF00000001
            // final MDS: reduce each lane mod p, pack 4 lanes/word, write return words directly (no ss round-trip)
            let r := mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 25), mul(v1, 15)), mul(v2, 41)), shl(4, v3)), shl(1, v4)), mul(v5, 28)), mul(v8, 39)), mul(v9, 18)), mul(v10, 34)), mul(v11, 20)), mul(add(v6, v7), 13)), p)
            r := or(r, shl(64, mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 20), mul(v1, 17)), mul(v2, 15)), mul(v3, 41)), shl(4, v4)), shl(1, v5)), mul(v6, 28)), mul(v9, 39)), mul(v10, 18)), mul(v11, 34)), mul(add(v7, v8), 13)), p)))
            r := or(r, shl(128, mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 34), mul(v1, 20)), mul(v2, 17)), mul(v3, 15)), mul(v4, 41)), shl(4, v5)), shl(1, v6)), mul(v7, 28)), mul(v10, 39)), mul(v11, 18)), mul(add(v8, v9), 13)), p)))
            r := or(r, shl(192, mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 18), mul(v1, 34)), mul(v2, 20)), mul(v3, 17)), mul(v4, 15)), mul(v5, 41)), shl(4, v6)), shl(1, v7)), mul(v8, 28)), mul(v11, 39)), mul(add(v9, v10), 13)), p)))
            mstore(0, r)
            r := mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 39), mul(v1, 18)), mul(v2, 34)), mul(v3, 20)), mul(v4, 17)), mul(v5, 15)), mul(v6, 41)), shl(4, v7)), shl(1, v8)), mul(v9, 28)), mul(add(v10, v11), 13)), p)
            r := or(r, shl(64, mod(add(add(add(add(add(add(add(add(add(add(mul(v1, 39), mul(v2, 18)), mul(v3, 34)), mul(v4, 20)), mul(v5, 17)), mul(v6, 15)), mul(v7, 41)), shl(4, v8)), shl(1, v9)), mul(v10, 28)), mul(add(v11, v0), 13)), p)))
            r := or(r, shl(128, mod(add(add(add(add(add(add(add(add(add(add(mul(v2, 39), mul(v3, 18)), mul(v4, 34)), mul(v5, 20)), mul(v6, 17)), mul(v7, 15)), mul(v8, 41)), shl(4, v9)), shl(1, v10)), mul(v11, 28)), mul(add(v0, v1), 13)), p)))
            r := or(r, shl(192, mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 28), mul(v3, 39)), mul(v4, 18)), mul(v5, 34)), mul(v6, 20)), mul(v7, 17)), mul(v8, 15)), mul(v9, 41)), shl(4, v10)), shl(1, v11)), mul(add(v1, v2), 13)), p)))
            mstore(32, r)
            r := mod(add(add(add(add(add(add(add(add(add(add(shl(1, v0), mul(v1, 28)), mul(v4, 39)), mul(v5, 18)), mul(v6, 34)), mul(v7, 20)), mul(v8, 17)), mul(v9, 15)), mul(v10, 41)), shl(4, v11)), mul(add(v2, v3), 13)), p)
            r := or(r, shl(64, mod(add(add(add(add(add(add(add(add(add(add(shl(4, v0), shl(1, v1)), mul(v2, 28)), mul(v5, 39)), mul(v6, 18)), mul(v7, 34)), mul(v8, 20)), mul(v9, 17)), mul(v10, 15)), mul(v11, 41)), mul(add(v3, v4), 13)), p)))
            r := or(r, shl(128, mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 41), shl(4, v1)), shl(1, v2)), mul(v3, 28)), mul(v6, 39)), mul(v7, 18)), mul(v8, 34)), mul(v9, 20)), mul(v10, 17)), mul(v11, 15)), mul(add(v4, v5), 13)), p)))
            r := or(r, shl(192, mod(add(add(add(add(add(add(add(add(add(add(mul(v0, 15), mul(v1, 41)), shl(4, v2)), shl(1, v3)), mul(v4, 28)), mul(v7, 39)), mul(v8, 18)), mul(v9, 34)), mul(v10, 20)), mul(v11, 17)), mul(add(v5, v6), 13)), p)))
            mstore(64, r)
      }
    }
  }
}
