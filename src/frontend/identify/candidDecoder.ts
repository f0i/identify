// candidDecoder.ts
import { Principal } from "@dfinity/principal";
import { uint8ArrayToHex } from "./utils";

/**
 * Custom error class for Candid decoding issues.
 * Includes the byte index where the error occurred.
 */
export class CandidError extends Error {
  constructor(
    message: string,
    public index: number,
  ) {
    super(message);
    this.name = "CandidError";
  }
}

/**
 * Interface for the result returned by the decodeCandid function.
 */
export type DecodeResult =
  | { ok: any }
  | { warning: { data: any; msg: string; index: number } }
  | { error: { data?: any; msg: string; index: number } };

/**
 * A utility class for reading bytes from a Uint8Array buffer.
 * Keeps track of the current reading offset and provides various read methods.
 */
class ByteReader {
  private offset: number = 0;
  private dataView: DataView; // For reading multi-byte numbers (e.g., floats, fixed-size integers)

  constructor(private buffer: Uint8Array) {
    this.dataView = new DataView(
      buffer.buffer,
      buffer.byteOffset,
      buffer.byteLength,
    );
  }

  /**
   * Checks if there are more bytes to read in the buffer.
   * @returns True if more bytes are available, false otherwise.
   */
  hasMore(): boolean {
    return this.offset < this.buffer.length;
  }

  /**
   * Reads a single byte from the current offset and advances the offset.
   * @returns The byte read.
   * @throws CandidError if attempting to read beyond the buffer end.
   */
  readByte(): number {
    if (!this.hasMore()) {
      throw new CandidError(
        "Unexpected end of buffer when reading a single byte.",
        this.offset,
      );
    }
    const byte = this.buffer[this.offset];
    this.offset++;
    return byte;
  }

  /**
   * Reads a specified number of bytes from the current offset and advances the offset.
   * @param length The number of bytes to read.
   * @returns A Uint8Array containing the read bytes.
   * @throws CandidError if not enough bytes are available to read the specified length.
   */
  readBytes(length: number): Uint8Array {
    if (this.offset + length > this.buffer.length) {
      throw new CandidError(
        `Not enough bytes to read. Expected ${length}, but only ${this.buffer.length - this.offset} available.`,
        this.offset,
      );
    }
    const bytes = this.buffer.slice(this.offset, this.offset + length);
    this.offset += length;
    return bytes;
  }

  /**
   * Reads a LEB128 encoded unsigned integer (used for 'nat' and lengths).
   * @returns The decoded unsigned integer as a BigInt.
   */
  readULEB128(): bigint {
    let result = 0n;
    let shift = 0n;
    let byte;
    do {
      byte = this.readByte();
      result |= (BigInt(byte) & 0x7fn) << shift; // Take lower 7 bits and append
      shift += 7n;
    } while ((byte & 0x80) !== 0); // Continue if MSB is set
    return result;
  }

  /**
   * Reads a LEB128 encoded signed integer (used for 'int' and type codes).
   * @returns The decoded signed integer as a BigInt.
   */
  readSLEB128(): bigint {
    let result = 0n;
    let shift = 0n;
    let byte;
    do {
      byte = this.readByte();
      result |= (BigInt(byte) & 0x7fn) << shift;
      shift += 7n;
    } while ((byte & 0x80) !== 0);

    // Sign extension: If the last byte's MSB (of the 7 bits) was set (0x40),
    // and we haven't filled up a 64-bit BigInt yet, extend the sign.
    if ((byte & 0x40) !== 0 && shift < 64n) {
      // Check for MSB of last 7-bit chunk
      result |= ~0n << shift; // Extend sign to fill higher bits
    }
    return result;
  }

  /**
   * Reads a UTF-8 string of a specified length.
   * @param length The length of the string in bytes.
   * @returns The decoded string.
   * @throws CandidError if not enough bytes are available.
   */
  readUtf8String(length: number): string {
    const bytes = this.readBytes(length);
    const decoder = new TextDecoder("utf-8", { fatal: true });
    return decoder.decode(bytes);
  }

  /**
   * Reads a fixed-size little-endian integer (e.g., nat16, int32, nat64).
   * @param byteLength The number of bytes to read (1, 2, 4, or 8).
   * @param signed Whether the number should be interpreted as signed.
   * @returns The decoded integer as a BigInt (important for 64-bit numbers).
   * @throws CandidError if not enough bytes are available.
   */
  readLittleEndian(byteLength: 1 | 2 | 4 | 8, signed: boolean = false): bigint {
    if (this.offset + byteLength > this.buffer.length) {
      throw new CandidError(
        `Not enough bytes for ${byteLength}-byte number (little-endian)`,
        this.offset,
      );
    }
    let value = 0n;
    for (let i = 0; i < byteLength; i++) {
      value |= BigInt(this.buffer[this.offset + i]) << BigInt(8 * i);
    }
    this.offset += byteLength;

    // Sign extension for fixed-width signed integers
    if (signed) {
      const msbMask = 1n << BigInt(byteLength * 8 - 1); // Mask for the most significant bit
      if ((value & msbMask) !== 0n) {
        // If MSB is set, it's a negative number
        value = value - (1n << BigInt(byteLength * 8)); // Subtract 2^(numBits) to get negative value
      }
    }
    return value;
  }

  /**
   * Reads a floating-point number (Float32 or Float64).
   * @param byteLength The number of bytes to read (4 for Float32, 8 for Float64).
   * @returns The decoded floating-point number.
   * @throws CandidError if not enough bytes are available.
   */
  readFloat(byteLength: 4 | 8): number {
    if (this.offset + byteLength > this.buffer.length) {
      throw new CandidError(
        `Not enough bytes for Float${byteLength * 8}`,
        this.offset,
      );
    }
    // Use DataView directly for efficient float reading
    let value: number;
    if (byteLength === 4) {
      value = this.dataView.getFloat32(this.offset, true); // true for little-endian
    } else {
      value = this.dataView.getFloat64(this.offset, true); // true for little-endian
    }
    this.offset += byteLength;
    return value;
  }

  /**
   * Gets the current reading offset (byte index) in the buffer.
   * @returns The current offset.
   */
  getCurrentOffset(): number {
    return this.offset;
  }
}

/**
 * Enum representing Candid primitive type codes (negative values).
 * These are used in the Candid binary format to denote type definitions.
 */
enum CandidTypeTag {
  Null = -1,
  Bool = -2,
  Nat = -3,
  Int = -4,
  Nat8 = -5,
  Nat16 = -6,
  Nat32 = -7,
  Nat64 = -8,
  Int8 = -9,
  Int16 = -10,
  Int32 = -11,
  Int64 = -12,
  Float32 = -13,
  Float64 = -14,
  Text = -15,
  Reserved = -16,
  Empty = -17, // Placeholder, usually no encoded value

  // Composite Type Definition Codes (these appear in the type table)
  Opt = -18,
  Vec = -19,
  Record = -20,
  Variant = -21,
  Func = -22,
  Service = -23,
  Principal = -24, // Principal is also a composite type, but encoded like a primitive value
}

/**
 * Base interface for all Candid type definitions parsed from the type table.
 */
interface CandidTypeDefinition {
  tag: CandidTypeTag | number; // Can be a primitive tag or a positive type table index (recursive)
}

/**
 * Type definition for a Candid Record.
 */
interface RecordTypeDefinition extends CandidTypeDefinition {
  tag: CandidTypeTag.Record;
  // Fields are sorted by their ID (hash) in increasing order.
  fields: { id: bigint; typeIdx: bigint }[]; // id is the field hash, typeIdx is its type's index in typeTable
}

/**
 * Type definition for a Candid Variant.
 */
interface VariantTypeDefinition extends CandidTypeDefinition {
  tag: CandidTypeTag.Variant;
  // Options are sorted by their ID (hash) in increasing order.
  options: { id: bigint; typeIdx: bigint }[]; // id is the option hash, typeIdx is its type's index in typeTable
}

/**
 * Type definition for a Candid Option.
 */
interface OptTypeDefinition extends CandidTypeDefinition {
  tag: CandidTypeTag.Opt;
  innerTypeIdx: bigint; // The type index of the value contained within the Option
}

/**
 * Type definition for a Candid Vector.
 */
interface VecTypeDefinition extends CandidTypeDefinition {
  tag: CandidTypeTag.Vec;
  elementTypeIdx: bigint; // The type index of elements within the Vector
}

/**
 * Type definition for a Candid Func.
 */
interface FuncTypeDefinition extends CandidTypeDefinition {
  tag: CandidTypeTag.Func;
  argTypeIdxs: bigint[]; // Type indices of function arguments
  retTypeIdxs: bigint[]; // Type indices of function return values
  modes: string[]; // e.g., ['query'], ['oneway']
}

/**
 * Type definition for a Candid Service.
 */
interface ServiceTypeDefinition extends CandidTypeDefinition {
  tag: CandidTypeTag.Service;
  // Methods mapping method name string to its function type index.
  methods: { name: string; funcTypeIdx: bigint }[];
}

/**
 * Creates a lookup map from an array of string field names.
 * Each string name is converted to its hash and used as the key.
 * @param names An array of string field names.
 * @returns A Record where keys are hashes and values are the original field names.
 */
export function createNameLookup(names: string[]): Record<number, string> {
  const map: Record<number, string> = {};
  for (const name of names) {
    const hash = fieldHash(name);
    if (map[hash]) {
      map[hash] += `|${name}`;
      console.warn(
        "Hash collision or duplicate between field names:",
        map[hash],
      );
    } else {
      map[hash] = name;
    }
  }
  return map;
}

function fieldHash(name: string): number {
  const utf8 = new TextEncoder().encode(name);
  const p = 223; // The prime base for the polynomial hash
  const mod = 2 ** 32; // The modulus, ensuring the hash remains a 32-bit unsigned integer

  let hash = 0; // Initialize the hash accumulator

  // Iterate over each byte in the UTF-8 encoded string
  for (let i = 0; i < utf8.length; i++) {
    const c = utf8[i]; // Get the current byte value
    // Apply the polynomial hash formula: (previous_hash * base + current_byte) % modulus
    hash = (hash * p + c) % mod;
  }

  // The hash is already within the 32-bit unsigned range due to the modulo operation
  return hash;
}

/**
 * Main function to decode Candid binary data.
 * It parses the Candid header (magic, type table, argument types)
 * and then decodes the actual values.
 *
 * @param buffer The Uint8Array containing the Candid binary data.
 * @param fieldNamesMap Optional map of field IDs (bigint) to human-readable names (string).
 * Used to resolve numeric field IDs in records/variants to actual names.
 * @returns A DecodeResult object containing the decoded data, or error details.
 */
export function decodeCandid(
  buffer: Uint8Array,
  fieldNamesMap?: Record<number, string>,
): DecodeResult {
  const reader = new ByteReader(buffer);
  let decodedData: any = null;
  let errorMsg: string | null = null;
  let errorIdx: number | null = null;
  // Stores parsed type definitions, accessible by their index (0-based)
  const typeTable: CandidTypeDefinition[] = [];

  try {
    // --- 1. Read Magic bytes "DIDL" (0x44 0x49 0x44 0x4C) ---
    const magic = reader.readBytes(4);
    if (
      magic[0] !== 0x44 ||
      magic[1] !== 0x49 ||
      magic[2] !== 0x44 ||
      magic[3] !== 0x4c
    ) {
      throw new CandidError("Invalid Candid magic bytes. Expected 'DIDL'.", 0);
    }

    // --- 2. Parse Type Table ---
    // This section defines all custom (composite) types used in the message.
    const numberOfTypes = reader.readULEB128();
    for (let i = 0; i < numberOfTypes; i++) {
      const currentParseOffset = reader.getCurrentOffset(); // Keep track for error reporting
      const typeCode = reader.readSLEB128(); // Reads the type tag for the current type definition
      let typeDef: CandidTypeDefinition;

      switch (Number(typeCode)) {
        case CandidTypeTag.Opt:
          const optInnerTypeIdx = reader.readSLEB128();
          typeDef = {
            tag: CandidTypeTag.Opt,
            innerTypeIdx: optInnerTypeIdx,
          } as OptTypeDefinition;
          break;
        case CandidTypeTag.Vec:
          const vecElementTypeIdx = reader.readSLEB128();
          typeDef = {
            tag: CandidTypeTag.Vec,
            elementTypeIdx: vecElementTypeIdx,
          } as VecTypeDefinition;
          break;
        case CandidTypeTag.Record:
          const numRecordFields = reader.readULEB128();
          const recordFields: { id: bigint; typeIdx: bigint }[] = [];
          for (let j = 0; j < numRecordFields; j++) {
            const id = reader.readULEB128(); // Field ID (hash of field name)
            const typeIdx = reader.readSLEB128(); // Type index of the field's value
            recordFields.push({ id, typeIdx });
          }
          // Candid spec requires record fields to be sorted by their ID for canonical representation.
          recordFields.sort((a, b) => Number(a.id - b.id));
          typeDef = {
            tag: CandidTypeTag.Record,
            fields: recordFields,
          } as RecordTypeDefinition;
          break;
        case CandidTypeTag.Variant:
          const numVariantOptions = reader.readULEB128();
          const variantOptions: { id: bigint; typeIdx: bigint }[] = [];
          for (let j = 0; j < numVariantOptions; j++) {
            const id = reader.readULEB128(); // Option ID (hash of option name)
            const typeIdx = reader.readSLEB128(); // Type index of the option's value
            variantOptions.push({ id, typeIdx });
          }
          // Candid spec requires variant options to be sorted by their ID for canonical representation.
          variantOptions.sort((a, b) => Number(a.id - b.id));
          typeDef = {
            tag: CandidTypeTag.Variant,
            options: variantOptions,
          } as VariantTypeDefinition;
          break;
        case CandidTypeTag.Func:
          const numFuncArgs = reader.readULEB128();
          const funcArgs: bigint[] = [];
          for (let j = 0; j < numFuncArgs; j++)
            funcArgs.push(reader.readSLEB128());
          const numFuncRets = reader.readULEB128();
          const funcRets: bigint[] = [];
          for (let j = 0; j < numFuncRets; j++)
            funcRets.push(reader.readSLEB128());
          const numFuncModes = reader.readULEB128();
          const funcModes: string[] = [];
          for (let j = 0; j < numFuncModes; j++) {
            const modeByte = reader.readByte();
            // 1: oneway, 2: query
            if (modeByte === 1) funcModes.push("oneway");
            else if (modeByte === 2) funcModes.push("query");
            else
              throw new CandidError(
                `Invalid function mode byte: ${modeByte}. Expected 1 or 2.`,
                reader.getCurrentOffset() - 1,
              );
          }
          typeDef = {
            tag: CandidTypeTag.Func,
            argTypeIdxs: funcArgs,
            retTypeIdxs: funcRets,
            modes: funcModes,
          } as FuncTypeDefinition;
          break;
        case CandidTypeTag.Service:
          const numServiceMethods = reader.readULEB128();
          const serviceMethods: { name: string; funcTypeIdx: bigint }[] = [];
          for (let j = 0; j < numServiceMethods; j++) {
            const nameLen = Number(reader.readULEB128());
            const name = reader.readUtf8String(nameLen);
            const funcTypeIdx = reader.readSLEB128(); // Points to a FuncTypeDefinition in the type table
            serviceMethods.push({ name, funcTypeIdx });
          }
          typeDef = {
            tag: CandidTypeTag.Service,
            methods: serviceMethods,
          } as ServiceTypeDefinition;
          break;
        default:
          throw new CandidError(
            `Unexpected type code (${typeCode}) in type table definition at index ${i}.`,
            currentParseOffset,
          );
      }
      typeTable.push(typeDef);
    }

    // --- 3. Parse Message Argument Types ---
    const numberOfArgTypes = reader.readULEB128();
    const argTypeIndices: bigint[] = [];
    for (let i = 0; i < numberOfArgTypes; i++) {
      const typeIdx = reader.readSLEB128();
      const typeCode = Number(typeIdx);

      // Reference types cannot be used directly as arguments.
      if (
        typeCode === CandidTypeTag.Service ||
        typeCode === CandidTypeTag.Func
      ) {
        throw new CandidError(
          `Reference type ${typeCode} cannot be used directly as an argument. It must be in the type table.`,
          reader.getCurrentOffset() - 1,
        );
      }
      argTypeIndices.push(typeIdx);
    }

    // --- 4. Decode Values ---
    const decodedValues: any[] = [];
    for (let i = 0; i < argTypeIndices.length; i++) {
      const typeOrIndex = argTypeIndices[i];
      decodedValues.push(
        decodeValue(reader, typeOrIndex, typeTable, fieldNamesMap),
      );
    }

    // --- 5. Check for trailing bytes ---
    if (reader.hasMore()) {
      throw new CandidError(
        "Trailing bytes found after decoding all expected values.",
        reader.getCurrentOffset(),
      );
    }

    decodedData = decodedValues;
    return { ok: decodedData };
  } catch (e) {
    // Centralized error handling
    if (e instanceof CandidError) {
      errorMsg = e.message;
      errorIdx = e.index;
    } else if (e instanceof Error) {
      errorMsg = `An unexpected JavaScript error occurred: ${e.message}`;
      errorIdx = reader.getCurrentOffset(); // Best guess for location
    } else {
      errorMsg = "An unknown error occurred during decoding.";
      errorIdx = reader.getCurrentOffset();
    }
    return {
      error: {
        msg: errorMsg,
        index: errorIdx,
        data: decodedData !== null ? decodedData : undefined,
      },
    };
  }
}

/**
 * Helper function to decode a principal value from the byte stream.
 * @param reader The ByteReader instance.
 * @returns The decoded Principal object.
 */
function decodePrincipalValue(reader: ByteReader): Principal {
  const principalTag = reader.readByte();
  if (principalTag !== 0x01) {
    throw new CandidError(
      `Unsupported principal tag: ${principalTag}. Expected 1.`,
      reader.getCurrentOffset() - 1,
    );
  }
  const principalLen = Number(reader.readULEB128());
  if (principalLen > 29) {
    throw new CandidError(
      `Invalid principal length: ${principalLen}. Must be at most 29 bytes.`,
      reader.getCurrentOffset() - 1,
    );
  }
  const bytes = reader.readBytes(principalLen);
  return Principal.fromUint8Array(bytes);
}

/**
 * Recursively decodes a Candid value based on its type tag or type table index.
 */
function decodeValue(
  reader: ByteReader,
  typeOrIndex: bigint,
  typeTable: CandidTypeDefinition[],
  fieldNamesMap?: Record<number, string>,
): any {
  let currentTypeTag: number;
  let typeDef: CandidTypeDefinition | undefined;

  if (typeOrIndex >= 0) {
    if (typeOrIndex >= typeTable.length) {
      throw new CandidError(
        `Type index ${typeOrIndex} is out of bounds for type table of size ${typeTable.length}.`,
        reader.getCurrentOffset(),
      );
    }
    typeDef = typeTable[Number(typeOrIndex)];
    currentTypeTag = Number(typeDef.tag);
  } else {
    currentTypeTag = Number(typeOrIndex);
  }

  switch (currentTypeTag) {
    case CandidTypeTag.Null:
      return null;
    case CandidTypeTag.Bool:
      const boolByte = reader.readByte();
      if (boolByte === 0) return false;
      if (boolByte === 1) return true;
      throw new CandidError(
        `Invalid boolean value: ${boolByte}. Expected 0 (false) or 1 (true).`,
        reader.getCurrentOffset() - 1,
      );
    case CandidTypeTag.Nat:
      return reader.readULEB128();
    case CandidTypeTag.Int:
      return reader.readSLEB128();
    case CandidTypeTag.Nat8:
      return reader.readByte();
    case CandidTypeTag.Nat16:
      return Number(reader.readLittleEndian(2, false));
    case CandidTypeTag.Nat32:
      return Number(reader.readLittleEndian(4, false));
    case CandidTypeTag.Nat64:
      return reader.readLittleEndian(8, false);
    case CandidTypeTag.Int8:
      return Number(reader.readLittleEndian(1, true));
    case CandidTypeTag.Int16:
      return Number(reader.readLittleEndian(2, true));
    case CandidTypeTag.Int32:
      return Number(reader.readLittleEndian(4, true));
    case CandidTypeTag.Int64:
      return reader.readLittleEndian(8, true);
    case CandidTypeTag.Float32:
      return reader.readFloat(4);
    case CandidTypeTag.Float64:
      return reader.readFloat(8);
    case CandidTypeTag.Text:
      const textLength = Number(reader.readULEB128());
      return reader.readUtf8String(textLength);
    case CandidTypeTag.Reserved:
      return null;
    case CandidTypeTag.Empty:
      throw new CandidError(
        "Attempted to decode 'empty' type as a value. This type has no encoded form.",
        reader.getCurrentOffset(),
      );
    case CandidTypeTag.Principal:
    case CandidTypeTag.Service:
      return decodePrincipalValue(reader);
    case CandidTypeTag.Opt: {
      const optDef = typeDef as OptTypeDefinition;
      const presentByte = reader.readByte();
      if (presentByte === 0) {
        return [];
      } else if (presentByte === 1) {
        return [
          decodeValue(reader, optDef.innerTypeIdx, typeTable, fieldNamesMap),
        ];
      } else {
        throw new CandidError(
          `Invalid option tag: ${presentByte}. Expected 0 or 1.`,
          reader.getCurrentOffset() - 1,
        );
      }
    }
    case CandidTypeTag.Vec: {
      const vecDef = typeDef as VecTypeDefinition;
      const vectorLength = Number(reader.readULEB128());
      const elements: any[] = [];
      for (let i = 0; i < vectorLength; i++) {
        elements.push(
          decodeValue(reader, vecDef.elementTypeIdx, typeTable, fieldNamesMap),
        );
      }
      return elements;
    }
    case CandidTypeTag.Record: {
      const recordDef = typeDef as RecordTypeDefinition;
      const record: { [key: string]: any } = {};
      for (const field of recordDef.fields) {
        const fieldKey =
          fieldNamesMap?.[Number(field.id)] || `_${field.id.toString()}`;
        record[fieldKey] = decodeValue(
          reader,
          field.typeIdx,
          typeTable,
          fieldNamesMap,
        );
      }
      return record;
    }
    case CandidTypeTag.Variant: {
      const variantDef = typeDef as VariantTypeDefinition;
      const variantIdx = Number(reader.readULEB128());
      if (variantIdx >= variantDef.options.length) {
        throw new CandidError(
          `Variant option index ${variantIdx} out of bounds. Variant has ${variantDef.options.length} options.`,
          reader.getCurrentOffset() - 1,
        );
      }
      const selectedOption = variantDef.options[variantIdx];
      const variantValue = decodeValue(
        reader,
        selectedOption.typeIdx,
        typeTable,
        fieldNamesMap,
      );
      const optionKey =
        fieldNamesMap?.[Number(selectedOption.id)] ||
        `_${selectedOption.id.toString()}`;
      return { [optionKey]: variantValue };
    }
    case CandidTypeTag.Func: {
      const funcTag = reader.readByte();
      if (funcTag !== 0x01) {
        throw new CandidError(
          `Unsupported function tag: ${funcTag}. Expected 1 for reference type.`,
          reader.getCurrentOffset() - 1,
        );
      }
      const principal = decodePrincipalValue(reader);
      const funcMethodNameLen = Number(reader.readULEB128());
      const funcMethodName = reader.readUtf8String(funcMethodNameLen);
      return [principal, funcMethodName];
    }
    default:
      throw new CandidError(
        `Unsupported or unknown Candid type tag: ${currentTypeTag} (resolved from index ${typeOrIndex}).`,
        reader.getCurrentOffset(),
      );
  }
}
