#!/usr/bin/env python3
"""POD2 SMT reference implementation (the *spec* the Solidity must match).

Ported from 0xPARC/pod2 rev 9376e242 (src/backends/plonky2/primitives/merkletree/mod.rs)
and 0xPARC/plonky2 rev 109d517d (Poseidon-Goldilocks).

Validated: perm([0]*12)[0] == 0x3c18a9786cb0b359 (plonky2 official test vector). ✔

Run `python3 poseidon_reference.py` to print the test vectors baked into the Foundry test.
"""

P = (1 << 64) - (1 << 32) + 1  # Goldilocks

# plonky2 Goldilocks MDS (poseidon_goldilocks.rs)
CIRC = [17, 15, 41, 16, 2, 28, 13, 13, 39, 18, 34, 20]
DIAG = [8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

# The 360 ALL_ROUND_CONSTANTS (layout ARC[12*round + lane], 30 rounds = 4 full + 22 partial
# + 4 full) are NOT inlined here. They are the authoritative source in
# src/PoseidonGoldilocksConstants.sol (2880 packed big-endian bytes, generated from plonky2).
# load_arc() reads them back so this reference and the Solidity share one source of truth.

import os
import re


def load_arc():
    """Read the 360 constants back out of the generated Solidity constants file."""
    sol = os.path.join(os.path.dirname(__file__), "..", "src", "PoseidonGoldilocksConstants.sol")
    txt = open(sol).read()
    m = re.search(r'hex"([0-9a-fA-F]+)"', txt)
    raw = bytes.fromhex(m.group(1))
    assert len(raw) == 2880
    return [int.from_bytes(raw[8 * i:8 * i + 8], "big") for i in range(360)]


def sbox(x):
    return pow(x, 7, P)


def const_layer(st, rc, arc):
    return [(st[i] + arc[12 * rc + i]) % P for i in range(12)]


def mds(st):
    out = [0] * 12
    for r in range(12):
        s = 0
        for i in range(12):
            s += st[(i + r) % 12] * CIRC[i]
        s += st[r] * DIAG[r]
        out[r] = s % P
    return out


def permute(st, arc):
    st = [x % P for x in st]
    rc = 0
    for _ in range(4):
        st = const_layer(st, rc, arc); st = [sbox(x) for x in st]; st = mds(st); rc += 1
    for _ in range(22):
        st = const_layer(st, rc, arc); st[0] = sbox(st[0]); st = mds(st); rc += 1
    for _ in range(4):
        st = const_layer(st, rc, arc); st = [sbox(x) for x in st]; st = mds(st); rc += 1
    return st


def hash_with_flag(flag, inputs, arc):
    assert len(inputs) == 8
    st = [flag] * 12
    for i in range(8):
        st[i] = inputs[i] % P
    return permute(st, arc)[0:4]


def kv_hash(key, value, arc):
    if value is None:
        return [0, 0, 0, 0]
    return hash_with_flag(1, list(key) + list(value), arc)


def node_hash(left, right, arc):
    if left == [0, 0, 0, 0] and right == [0, 0, 0, 0]:
        return [0, 0, 0, 0]
    return hash_with_flag(2, list(left) + list(right), arc)


def key_bit(key, n):
    return (key[n // 64] >> (n % 64)) & 1


def compute_root_from_leaf(key, value, siblings, arc):
    """value=None -> empty/non-membership; siblings deepest-last."""
    h = kv_hash(key, value, arc)
    for i in range(len(siblings) - 1, -1, -1):
        sib = siblings[i]
        if key_bit(key, i):
            inp = list(sib) + list(h)   # h is RIGHT child
        else:
            inp = list(h) + list(sib)   # h is LEFT child
        h = hash_with_flag(2, inp, arc)
    return h


if __name__ == "__main__":
    arc = load_arc()
    pz = permute([0] * 12, arc)
    assert pz[0] == 0x3c18a9786cb0b359, "Poseidon mismatch vs plonky2 official vector!"
    print("permute([0]*12) matches plonky2 official test vector ✔")

    def lit(v):
        return "[" + ", ".join(str(x) for x in v) + "]"

    def show(name, v):
        print(f"{name} = {lit(v)}")

    # --- single-hash vectors (leaf flag=1, node flag=2) ---
    show("KV_1_8", kv_hash([1, 2, 3, 4], [5, 6, 7, 8], arc))
    show("NODE_1_8", node_hash([1, 2, 3, 4], [5, 6, 7, 8], arc))

    # --- empty leaf (non-membership leaf) must hash to zeros ---
    assert kv_hash([7, 7, 7, 7], None, arc) == [0, 0, 0, 0], "empty leaf must be zeros"
    print("kv_hash(empty) == [0,0,0,0]  (non-membership leaf) ✔")

    # --- depth table: membership root with a mixed-bit key (exercises both left/right placement) ---
    KEY = [0x0123456789ABCDEF, 0, 0, 0]
    VAL = [9, 0, 0, 0]
    def sibs(d):
        return [[100 + i, 200 + i, 300 + i, 400 + i] for i in range(d)]
    print("\n// depth -> membership root (key=0x0123456789abcdef, value=[9,0,0,0])")
    for d in (1, 8, 16, 20, 32):
        print(f"ROOT_D{d} = {lit(compute_root_from_leaf(KEY, VAL, sibs(d), arc))}")

    # --- non-membership (empty leaf) root at depth 8, same key/siblings ---
    print(f"\nNONMEMB_EMPTY_D8 = {lit(compute_root_from_leaf(KEY, None, sibs(8), arc))}")

    # --- single-leaf tree root (used by the empty-tree insert test) ---
    show("LEAF_K0_V9", kv_hash([0, 0, 0, 0], [9, 0, 0, 0], arc))
