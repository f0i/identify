import { createNameLookup, decodeCandid } from "./candidDecoder";
import { Principal } from "@dfinity/principal";

const raw = String.raw;

/**
 * Converts a string with backslash escapes (e.g., "\\00") into a Uint8Array.
 * @param str The escaped string.
 * @returns A Uint8Array representation of the string.
 */
function fromEscapedString(str: string): Uint8Array {
  // Use a regex to match either an octal escape sequence or any other character.
  const parts = str.match(/\\([0-9a-fA-F]{2})|./g);
  if (!parts) {
    return new Uint8Array();
  }
  const bytes = parts.map((part) => {
    if (part.startsWith("\\")) {
      // It's an hex escape, parse it as base 16.
      return parseInt(part.slice(1), 16);
    } else {
      // It's a regular character, get its char code.
      return part.charCodeAt(0);
    }
  });
  return new Uint8Array(bytes);
}

function fromHexString(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) {
    throw new Error("Hex string must have an even length");
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}

const lookupTable = createNameLookup([
  "",
  "Ok",
  "Err",
  "foo",
  "bar",
  "baz",
  "head",
  "tail",
  "method",
  "params",
  "canisterId",
  "sender",
  "arg",
  "from_subaccount",
  "to",
  "owner",
  "memo",
  "amount",
  "fee",
  "subaccount",
  "created_at_time",
]);
console.log("Lookup table:", lookupTable);

describe("candidDecoder", () => {
  test("icrc1_transfer", () => {
    // test 4449444c066d7b6e006c02b3b0dac30368ad86ca8305016e7d6e786c06fbca0102c6fcb60203ba89e5c20401a2de94eb060182f3f3910c04d8a38ca80d7d0105011d5dd64083ce6039cdece839138afec5067f510c748f4faae09a5b011a020000000000808080f5ddb8ebe4b56c
    expect(
      decodeCandid(
        fromHexString(
          "4449444c066d7b6e006c02b3b0dac30368ad86ca8305016e7d6e786c06fbca0102c6fcb60203ba89e5c20401a2de94eb060182f3f3910c04d8a38ca80d7d0105011d5dd64083ce6039cdece839138afec5067f510c748f4faae09a5b011a020000000000808080f5ddb8ebe4b56c",
        ),
        lookupTable,
      ),
    ).toEqual({
      ok: [
        {
          created_at_time: [],
          from_subaccount: [],
          amount: 1000000000000000000000n,
          fee: [],
          memo: [],
          to: {
            subaccount: [],
            owner: Principal.fromText(
              "6pfju-rc52z-aihtt-ahhg6-z2bzc-ofp5r-igp5i-qy5ep-j6vob-gs3ae-nae",
            ),
          },
        },
      ],
    });
  });
});

describe("prim.test.did", () => {
  test("fundamentally wrong", () => {
    // assert blob ""              !: () "empty";
    expect(decodeCandid(fromEscapedString(raw``))).toMatchObject({
      error: { msg: expect.stringContaining("Not enough bytes") },
    });
    // assert blob "\00\00"        !: () "no magic bytes";
    expect(decodeCandid(fromEscapedString(raw`\00\00`))).toHaveProperty(
      "error",
    );
    // assert blob "DADL"          !: () "wrong magic bytes";
    expect(decodeCandid(fromEscapedString(raw`DADL`))).toHaveProperty("error");
    // assert blob "DADL\00\00"    !: () "wrong magic bytes";
    expect(decodeCandid(fromEscapedString(raw`DADL\00\00`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\80\00\00"  : () "overlong typ table length";
    expect(decodeCandid(fromEscapedString(raw`DIDL\80\00\00`))).toEqual({
      ok: [],
    });
    // assert blob "DIDL\00\80\00"  : () "overlong arg length";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\80\00`))).toEqual({
      ok: [],
    });
  });

  test("nullary input", () => {
    // assert blob "DIDL\00\00"     : ();
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\00`))).toEqual({
      ok: [],
    });
    // assert blob "DIDL\00\00\00" !: () "nullary: too long";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\00\00`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\00\01\7f"  : () "Additional parameters are ignored";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7f`))).toEqual({
      ok: [null],
    });
    // assert blob "DIDL\00\01\6e" !: () "Not a primitive type";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\6e`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\00\01\5e" !: () "Out of range type";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\5e`))).toHaveProperty(
      "error",
    );
  });

  test("Missing arguments", () => {
    // assert blob "DIDL\00\00" !: (nat) "missing argument: nat fails";
    // assert blob "DIDL\00\00" !: (empty) "missing argument: empty fails";
    // assert blob "DIDL\00\00" == "(null)" : (null) "missing argument: null";
    // assert blob "DIDL\00\00" == "(null)" : (opt empty) "missing argument: opt empty";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\00`))).toEqual({
      ok: [],
    });
  });

  test("primitive types: null, bool", () => {
    // assert blob "DIDL\00\01\7f" : (null);
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7f`))).toEqual({
      ok: [null],
    });
    // assert blob "DIDL\00\01\7e" !: (null) "wrong type";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7e`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\00\01\7f\00" !: (null) "null: too long";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\7f\00`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\7e\00" == "(false)" : (bool) "bool: false";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7e\00`))).toEqual({
      ok: [false],
    });
    // assert blob "DIDL\00\01\7e\01" == "(true)" : (bool) "bool: true";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7e\01`))).toEqual({
      ok: [true],
    });
    // assert blob "DIDL\00\01\7e" !: (bool) "bool: missing";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7e`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\00\01\7e\02" !: (bool) "bool: out of range";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\7e\02`)),
    ).toHaveProperty("error");
  });

  test("primitive types: nat", () => {
    // assert blob "DIDL\00\01\7d\00" == "(0)" : (nat) "nat: 0";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7d\00`))).toEqual({
      ok: [0n],
    });
    // assert blob "DIDL\00\01\7d\01" == "(1)" : (nat) "nat: 1";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7d\01`))).toEqual({
      ok: [1n],
    });
    // assert blob "DIDL\00\01\7d\7f" == "(127)" : (nat) "nat: 0x7f";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7d\7f`))).toEqual({
      ok: [127n],
    });
    // assert blob "DIDL\00\01\7d\80\01" == "(128)" : (nat) "nat: leb (two bytes)";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7d\80\01`))).toEqual({
      ok: [128n],
    });
    // assert blob "DIDL\00\01\7d\ff\7f" == "(16383)" : (nat) "nat: leb (two bytes, all bits)";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7d\ff\7f`))).toEqual({
      ok: [16383n],
    });
    // assert blob "DIDL\00\01\7d\80" !: (nat) "nat: leb too short";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\7d\80`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\7d\80\00" == "(0)" : (nat) "nat: leb overlong";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7d\80\00`))).toEqual({
      ok: [0n],
    });
    // assert blob "DIDL\00\01\7d\80\80\98\f4\e9\b5\ca\6a" == "(60000000000000000)" : (nat) "nat: big number";
    expect(
      decodeCandid(
        fromEscapedString(raw`DIDL\00\01\7d\80\80\98\f4\e9\b5\ca\6a`),
      ),
    ).toEqual({ ok: [60000000000000000n] });
  });

  test("primitive types: int", () => {
    // assert blob "DIDL\00\01\7c\00" == "(0)" : (int) "int: 0";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\00`))).toEqual({
      ok: [0n],
    });
    // assert blob "DIDL\00\01\7c\01" == "(1)" : (int) "int: 1";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\01`))).toEqual({
      ok: [1n],
    });
    // assert blob "DIDL\00\01\7c\7f" == "(-1)" : (int) "int: -1";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\7f`))).toEqual({
      ok: [-1n],
    });
    // assert blob "DIDL\00\01\7c\40" == "(-64)" : (int) "int: -64";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\40`))).toEqual({
      ok: [-64n],
    });
    // assert blob "DIDL\00\01\7c\80\01" == "(128)" : (int) "int: leb (two bytes)";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\80\01`))).toEqual({
      ok: [128n],
    });
    // assert blob "DIDL\00\01\7c\80" !: (int) "int: leb too short";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\80`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\7c\ff\00" == "(127)" : (int) "int: leb not overlong when signed";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\ff\00`))).toEqual({
      ok: [127n],
    });
    // assert blob "DIDL\00\01\7c\80\7f" == "(-128)" : (int) "int: leb not overlong when signed";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7c\80\7f`))).toEqual({
      ok: [-128n],
    });
  });

  test("primitive types: fixed-width numbers", () => {
    // assert blob "DIDL\00\01\7b\00" == "(0)" : (nat8) "nat8: 0";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7b\00`))).toEqual({
      ok: [0],
    });
    // assert blob "DIDL\00\01\7b\ff" == "(255)" : (nat8) "nat8: 255";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7b\ff`))).toEqual({
      ok: [255],
    });
    // assert blob "DIDL\00\01\7b" !: (nat8) "nat8: too short";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7b`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\00\01\7a\ff\ff" == "(65535)" : (nat16) "nat16: 65535";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7a\ff\ff`))).toEqual({
      ok: [65535],
    });
    // assert blob "DIDL\00\01\7a\00\00\00" !: (nat16) "nat16: too long";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\7a\00\00\00`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\79\ff\ff\ff\ff" == "(4294967295)" : (nat32) "nat32: 4294967295";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\79\ff\ff\ff\ff`)),
    ).toEqual({ ok: [4294967295] });
    // assert blob "DIDL\00\01\79" !: (nat32) "nat32: too short";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\79`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\00\01\78\ff\ff\ff\ff\ff\ff\ff\ff" == "(18446744073709551615)" : (nat64) "nat64: 18446744073709551615";
    expect(
      decodeCandid(
        fromEscapedString(raw`DIDL\00\01\78\ff\ff\ff\ff\ff\ff\ff\ff`),
      ),
    ).toEqual({ ok: [18446744073709551615n] });
    // assert blob "DIDL\00\01\77\ff" == "(-1)" : (int8) "int8: -1";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\77\ff`))).toEqual({
      ok: [-1],
    });
    // assert blob "DIDL\00\01\76\ff\ff" == "(-1)" : (int16) "int16: -1";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\76\ff\ff`))).toEqual({
      ok: [-1],
    });
    // assert blob "DIDL\00\01\75\ff\ff\ff\ff" == "(-1)" : (int32) "int32: -1";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\75\ff\ff\ff\ff`)),
    ).toEqual({ ok: [-1] });
    // assert blob "DIDL\00\01\74\ff\ff\ff\ff\ff\ff\ff\ff" == "(-1)" : (int64) "int64: -1";
    expect(
      decodeCandid(
        fromEscapedString(raw`DIDL\00\01\74\ff\ff\ff\ff\ff\ff\ff\ff`),
      ),
    ).toEqual({ ok: [-1n] });
  });

  test("primitive types: floats", () => {
    // assert blob "DIDL\00\01\73\00\00\40\40" == "(3.)" : (float32) "float32: 3";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\73\00\00\40\40`)),
    ).toEqual({ ok: [3.0] });
    // assert blob "DIDL\00\01\73\00\00\00\bf" == "(-0.5)" : (float32) "float32: -0.5";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\73\00\00\00\bf`)),
    ).toEqual({ ok: [-0.5] });
    // assert blob "DIDL\00\01\73\00\00" !: (float32) "float32: too short";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\73\00\00`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\72\00\00\00\00\00\00\08\40" == "(3.)" : (float64) "float64: 3";
    expect(
      decodeCandid(
        fromEscapedString(raw`DIDL\00\01\72\00\00\00\00\00\00\08\40`),
      ),
    ).toEqual({ ok: [3.0] });
    // assert blob "DIDL\00\01\72\00\00\00\00\00\00\e0\bf" == "(-0.5)" : (float64) "float64: -0.5";
    expect(
      decodeCandid(
        fromEscapedString(raw`DIDL\00\01\72\00\00\00\00\00\00\e0\bf`),
      ),
    ).toEqual({ ok: [-0.5] });
    // assert blob "DIDL\00\01\72\01\00\00\00\00\00\f0\7f" : (float64) "float64: NaN";
    expect(
      decodeCandid(
        fromEscapedString(raw`DIDL\00\01\72\01\00\00\00\00\00\f0\7f`),
      ),
    ).toEqual({ ok: [NaN] });
  });

  test("primitive types: text", () => {
    // assert blob "DIDL\00\01\71\00" == "(\"\")" : (text) "text: empty string";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\71\00`))).toEqual({
      ok: [""],
    });
    // assert blob "DIDL\00\01\71\06Motoko" == "(\"Motoko\")" : (text) "text: Motoko";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\71\06Motoko`)),
    ).toEqual({ ok: ["Motoko"] });
    // assert blob "DIDL\00\01\71\05Motoko" !: (text) "text: too long";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\71\05Motoko`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\71\07Motoko" !: (text) "text: too short";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\71\07Motoko`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\71\03\e2\98\83" == "(\"☃\")" : (text) "text: Unicode";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\71\03\e2\98\83`)),
    ).toEqual({ ok: ["☃"] });
    // assert blob "DIDL\00\01\71\03\e2\28\a1" !: (text) "text: Invalid utf8";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\71\03\e2\28\a1`)),
    ).toHaveProperty("error");
  });

  test("primitive types: reserved and empty", () => {
    // assert blob "DIDL\00\01\70" == blob "DIDL\00\01\7f" : (reserved) "reserved from null";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\70`))).toEqual({
      ok: [null],
    });
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7f`))).toEqual({
      ok: [null],
    });
    // assert blob "DIDL\00\01\70" == blob "DIDL\00\01\7e\01" : (reserved) "reserved from bool";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\7e\01`))).toEqual({
      ok: [true],
    });
    // assert blob "DIDL\00\01\6f" !: (empty) "cannot decode empty type";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\6f`))).toHaveProperty(
      "error",
    );
    // assert blob "DIDL\01\6e\6f\01\00\00" == "(null)" : (opt empty) "okay to decode non-empty value";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\01\6e\6f\01\00\00`)),
    ).toEqual({ ok: [[]] });
  });

  test("multiple arguments", () => {
    // assert blob "DIDL\00\0a\7f\7e\7d\7c\7f\70\7f\7b\7a\79\01\2a\2a\2a\2a\00\2a\00\00\00" == "(null, true, 42, 42, null, null, null, 42, 42, 42)"
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\00\0a\7f\7e\7d\7c\7f\70\7f\7b\7a\79\01\2a\2a\2a\2a\00\2a\00\00\00`,
        ),
      ),
    ).toEqual({
      ok: [null, true, 42n, 42n, null, null, null, 42, 42, 42],
    });
  });
});

describe("construct.test.did", () => {
  // TODO add other tests from construct.test.did
  test("record", () => {
    // assert blob "DIDL\02\6e\01\6c\02\a0\d2\ac\a8\04\7c\90\ed\da\e7\04\00\01\00\01\01\01\02\01\03\01\04\00"
    //             == "(opt record { head = 1; tail = opt record { head = 2; tail = opt record { head = 3; tail = opt record { head = 4; tail = null }}}})" : (List) "record: list";
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6e\01\6c\02\a0\d2\ac\a8\04\7c\90\ed\da\e7\04\00\01\00\01\01\01\02\01\03\01\04\00`,
        ),
        lookupTable,
      ),
    ).toEqual({
      ok: [
        [
          {
            head: 1n,
            tail: [
              {
                head: 2n,
                tail: [{ head: 3n, tail: [{ head: 4n, tail: [] }] }],
              },
            ],
          },
        ],
      ],
    });
  });
});

describe("reference.test.did", () => {
  test("principal", () => {
    // assert blob "DIDL\00\01\68\01\00" == "(principal \"aaaaa-aa\")" : (principal) "principal: ic0";
    expect(decodeCandid(fromEscapedString(raw`DIDL\00\01\68\01\00`))).toEqual({
      ok: [Principal.fromText("aaaaa-aa")],
    });
    // assert blob "DIDL\00\01\68\01\03\ca\ff\ee" == "(principal \"w7x7r-cok77-xa\")" : (principal) "principal";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\68\01\03\ca\ff\ee`)),
    ).toEqual({ ok: [Principal.fromText("w7x7r-cok77-xa")] });
    // assert blob "DIDL\00\01\68\01\09\ef\cd\ab\00\00\00\00\00\01" == "(principal \"2chl6-4hpzw-vqaaa-aaaaa-c\")" : (principal) "principal";
    expect(
      decodeCandid(
        fromEscapedString(raw`DIDL\00\01\68\01\09\ef\cd\ab\00\00\00\00\00\01`),
      ),
    ).toEqual({ ok: [Principal.fromText("2chl6-4hpzw-vqaaa-aaaaa-c")] });
    // assert blob "DIDL\00\01\68\03\ca\ff\ee" !: (principal) "principal: no tag";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\68\03\ca\ff\ee`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\68\01\03\ca\ff" !: (principal) "principal: too short";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\68\01\03\ca\ff`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\68\01\03\ca\ff\ee\ee" !: (principal) "principal: too long";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\68\01\03\ca\ff\ee\ee`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\01\68\01\00\01\03\ca\ff\ee" !: (principal) "principal: not construct";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\01\68\01\00\01\03\ca\ff\ee`)),
    ).toHaveProperty("error");
  });

  test("service", () => {
    // assert blob "DIDL\00\01\68\01\03\ca\ff\ee" !: (service {}) "service: not principal";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\68\01\03\ca\ff\ee`)),
    ).toHaveProperty("ok"); // Type mismatch can't be detected by this decoder.
    // assert blob "DIDL\00\01\69\01\03\ca\ff\ee" !: (service {}) "service: not primitive type";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\69\01\03\ca\ff\ee`)),
    ).toHaveProperty("error");
    // assert blob "DIDL\01\69\00\01\00\01\03\ca\ff\ee" == "(service \"w7x7r-cok77-xa\")" : (service {}) "service";
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\01\69\00\01\00\01\03\ca\ff\ee`)),
    ).toEqual({ ok: [Principal.fromText("w7x7r-cok77-xa")] });
    // assert blob "DIDL\02\6a\01\71\01\7d\00\69\01\03foo\00\01\01\01\03\ca\ff\ee" == "(service \"w7x7r-cok77-xa\")" : (service { foo : (text) -> (nat) }) "service";
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6a\01\71\01\7d\00\69\01\03foo\00\01\01\01\03\ca\ff\ee`,
        ),
      ),
    ).toEqual({ ok: [Principal.fromText("w7x7r-cok77-xa")] });
    // assert blob "DIDL\02\6a\01\71\01\7d\00\69\02\03foo\00\04foo\32\00\01\01\01\03\ca\ff\ee" !: (service { foo : (text) -> (nat); foo2 : (text) -> (nat) }) "service: too long";
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6a\01\71\01\7d\00\69\03\03foo\00\04foo\32\00\01\01\01\03\ca\ff\ee`,
        ),
      ),
    ).toHaveProperty("error");
    // assert blob "DIDL\02\6a\01\71\01\7d\00\69\02\04foo\32\00\03foo\00\01\01\01\03\ca\ff\ee" !: (service { foo : (text) -> (nat); foo2 : (text) -> (nat) }) "service: unsorted";
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6a\01\71\01\7d\00\69\02\04foo\32\00\03foo\00\01\01\01\03\ca\ff\ee`,
        ),
      ),
    ).toHaveProperty("ok"); // TODO: Check what this should return.
    // assert blob "DIDL\02\6a\01\71\01\7d\00\69\02\03foo\00\03foo\00\01\01\01\03\ca\ff\ee" !: (service { foo : (text) -> (nat) }) "service: duplicate";
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6a\01\71\01\7d\00\69\02\03foo\00\03foo\00\01\01\01\03\ca\ff\ee`,
        ),
      ),
    ).toHaveProperty("ok"); // TODO: Check what this should return.
  });

  test("function", () => {
    // assert blob "DIDL\01\6a\00\00\00\01\00\01\01\03\ca\ff\ee\01\61" == "(func \"w7x7r-cok77-xa\".\"a\")" : (func () -> ());
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\01\6a\00\00\00\01\00\01\01\03\ca\ff\ee\01\61`,
        ),
      ),
    ).toEqual({ ok: [[Principal.fromText("w7x7r-cok77-xa"), "a"]] });
    // assert blob "DIDL\01\6a\00\00\00\01\00\01\00\03\ca\ff\ee\01\61" !: (func () -> ());
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\01\6a\00\00\00\01\00\01\00\03\ca\ff\ee\01\61`,
        ),
      ),
    ).toHaveProperty("error");
    // assert blob "DIDL\02j\02|}\01\01\01\01i\00\01\00\01\01\00\04\f0\9f\90\82" == "(func \"aaaaa-aa\".\"🐂\")" : (func (int,nat) -> (service {}) query);
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02j\02|}\01\01\01\01i\00\01\00\01\01\00\04\f0\9f\90\82`,
        ),
      ),
    ).toEqual({ ok: [[Principal.fromText("aaaaa-aa"), "🐂"]] });
    // assert blob "DIDL\01\6a\01\68\01\7d\00\01\00\01\01\03\ca\ff\ee\03foo" == "(func \"w7x7r-cok77-xa\".foo)" : (func (principal) -> (nat));
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\01\6a\01\68\01\7d\00\01\00\01\01\03\ca\ff\ee\03foo`,
        ),
      ),
    ).toEqual({ ok: [[Principal.fromText("w7x7r-cok77-xa"), "foo"]] });
    // assert blob "DIDL\01\6a\01\71\01\7d\01\01\01\00\01\01\03\ca\ff\ee\03foo" == "(func \"w7x7r-cok77-xa\".foo)" : (func (text) -> (nat) query);
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\01\6a\01\71\01\7d\01\01\01\00\01\01\03\ca\ff\ee\03foo`,
        ),
      ),
    ).toEqual({ ok: [[Principal.fromText("w7x7r-cok77-xa"), "foo"]] });
    // assert blob "DIDL\01\6a\01\71\01\7d\01\03\01\00\01\01\03\ca\ff\ee\03foo" !: (func (text) -> (nat));
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\01\6a\01\71\01\7d\01\03\01\00\01\01\03\ca\ff\ee\03foo`,
        ),
      ),
    ).toHaveProperty("error");
    // assert blob "DIDL\00\01\6a\01\03\ca\ff\ee\01\61" !: (func () -> ());
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\00\01\6a\01\03\ca\ff\ee\01\61`)),
    ).toHaveProperty("error");
  });

  test("subtype", () => {
    // assert blob "DIDL\01\69\00\01\00\01\03\ca\ff\ee" !: (service { foo : (text) -> (nat) });
    expect(
      decodeCandid(fromEscapedString(raw`DIDL\01\69\00\01\00\01\03\ca\ff\ee`)),
    ).toHaveProperty("ok"); // Type mismatch can't be detected by this decoder.
    // assert blob "DIDL\02\6a\01\71\01\7d\01\01\69\01\03foo\00\01\01\01\03\ca\ff\ee" !: (service { foo : (text) -> (nat) });
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6a\01\71\01\7d\01\01\69\01\03foo\00\01\01\01\03\ca\ff\ee`,
        ),
      ),
    ).toHaveProperty("ok"); // Type mismatch can't be detected by this decoder.
    // assert blob "DIDL\02\6a\01\71\01\7d\00\69\01\03foo\00\01\01\01\03\ca\ff\ee" !: (service { foo : (text) -> (nat) query });
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6a\01\71\01\7d\00\69\01\03foo\00\01\01\01\03\ca\ff\ee`,
        ),
      ),
    ).toHaveProperty("ok"); // Type mismatch can't be detected by this decoder.
    // assert blob "DIDL\02\6a\01\71\01\7d\00\69\01\03foo\00\01\01\01\03\ca\ff\ee" == "(service \"w7x7r-cok77-xa\")" : (service {});
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\02\6a\01\71\01\7d\00\69\01\03foo\00\01\01\01\03\ca\ff\ee`,
        ),
      ),
    ).toEqual({ ok: [Principal.fromText("w7x7r-cok77-xa")] });
    // assert blob "DIDL\01\6a\00\00\00\01\00\01\01\03\ca\ff\ee\03foo" !: (func (text) -> (nat));
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\01\6a\00\00\00\01\00\01\01\03\ca\ff\ee\03foo`,
        ),
      ),
    ).toHaveProperty("ok"); // Type mismatch can't be detected by this decoder.
    // assert blob "DIDL\01\6a\01\71\01\7d\00\01\00\01\01\03\ca\ff\ee\03foo" == "(func \"w7x7r-cok77-xa\".foo)" : (func (text, opt text) -> ());
    expect(
      decodeCandid(
        fromEscapedString(
          raw`DIDL\01\6a\01\71\01\7d\00\01\00\01\01\03\ca\ff\ee\03foo`,
        ),
      ),
    ).toEqual({ ok: [[Principal.fromText("w7x7r-cok77-xa"), "foo"]] });
  });
});
