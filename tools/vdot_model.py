#!/usr/bin/env python3
"""Small reference model for the custom vdot.vv encoding and arithmetic.

This is not the RTL or NEMU implementation.  It is an independent check used
to generate test vectors and to verify the machine-code fields before those
vectors are put into assembly.
"""

MASK32 = (1 << 32) - 1


def encode_vdot(vd: int, vs2: int, vs1: int) -> int:
    """Encode vdot.vv vd, vs2, vs1 (assembly order vd, vs2, vs1)."""
    assert 0 <= vd < 32 and 0 <= vs2 < 32 and 0 <= vs1 < 32
    funct7 = 0b1111101
    funct3 = 0b000
    opcode = 0b1010111
    return ((funct7 << 25) | (vs2 << 20) | (vs1 << 15) |
            (funct3 << 12) | (vd << 7) | opcode)


def decode_vdot(word: int) -> dict:
    return {
        "funct7": (word >> 25) & 0x7F,
        "vs2": (word >> 20) & 0x1F,
        "vs1": (word >> 15) & 0x1F,
        "funct3": (word >> 12) & 0x7,
        "vd": (word >> 7) & 0x1F,
        "opcode": word & 0x7F,
    }


def s8(x: int) -> int:
    x &= 0xFF
    return x - 0x100 if x & 0x80 else x


def s32(x: int) -> int:
    x &= MASK32
    return x - (1 << 32) if x & (1 << 31) else x


def dot8(a: bytes, b: bytes) -> int:
    """Signed int8 dot product of the low eight bytes, wrapped to int32."""
    assert len(a) >= 8 and len(b) >= 8
    total = 0
    for i in range(8):
        total += s8(a[i]) * s8(b[i])
    return s32(total)


def main() -> None:
    word = encode_vdot(3, 1, 2)
    assert word == 0xFA1101D7, hex(word)
    print(f"vdot.vv v3, v1, v2 = 0x{word:08x}")
    print(decode_vdot(word))

    cases = [
        ("max-max", [127] * 8, [127] * 8, 129032),
        ("min-min", [-128] * 8, [-128] * 8, 131072),
        ("min-max", [-128] * 8, [127] * 8, -130048),
        ("cancel", [127, -127] * 4, [127] * 8, 0),
    ]
    for name, aa, bb, expected in cases:
        got = dot8(bytes(x & 0xFF for x in aa), bytes(x & 0xFF for x in bb))
        print(f"{name:8s} got={got:8d} expected={expected:8d}")
        assert got == expected


if __name__ == "__main__":
    main()
