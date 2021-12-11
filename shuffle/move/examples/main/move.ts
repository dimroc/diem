// Copyright (c) The Diem Core Contributors
// SPDX-License-Identifier: Apache-2.0

/**
 * Javascript/Typescript has a very loose type system, resulting in ambiguity
 * when trying to encode string values for onchain Move programs, a space that
 * has a very strong type system.
 *
 * Let's look at two examples:
 * 1)
 * invokeScriptFunction("0xDEADBEEF::Module::set_u64", [], ["9"]);
 * invokeScriptFunction("0xDEADBEEF::Module::set_ascii", [], ["9"]);
 *
 * In set_u64 , we want "9" to remain a string, because javascript does
 * not have support for integers, especially of the size u64. The proper encoding
 * happens in rust in the Dev API.
 *
 * In set_ascii, we want to send hex encoded bytes representing ascii on chain,
 * which would require us to hex encode the bytes representing "9".
 *
 * We cannot automatically infer the desired encoding without a signal from
 * the developer, hence the reason for a type system. *
 *
 * invokeScriptFunction("0xDEADBEEF::Module::set_u64", [], [U64("9")]);
 * invokeScriptFunction("0xDEADBEEF::Module::set_ascii", [], [Ascii("9")]);
 *
 * * NOTE: We could get the argument type of u64 for the script function
 * before encoding for this scenario, but please see the next scenario.
 *
 * 2)
 * invokeScriptFunction("0xDEADBEEF::Module::set_ascii", [], ["0xb1e55ed"])
 * invokeScriptFunction("0xDEADBEEF::Module::set_bytes", [], ["0xb1e55ed"])
 *
 * The first invocation, we would like to leave the string as is, the second,
 * we would like to hex encode.
 * To solve this, we introduce type signaling:
 * invokeScriptFunction("0xDEADBEEF::Module::set_ascii", [], [Ascii("0xb1e55ed")])
 * invokeScriptFunction("0xDEADBEEF::Module::set_bytes", [], [Hex("0xb1e55ed")])
 *
 * * NOTE: Both these script functions have argument type of vector<u8>, requiring
 * client side typing to indicate intent.
 * @module
 */

// deno-lint-ignore-file no-explicit-any

import * as util from "https://deno.land/std@0.85.0/node/util.ts";

export type MoveType = NumberEncoder | StringEncoder | Array<MoveType>; // Through recursion, supports arrays of arrays.
export type EncodedType = string | number | Array<EncodedType>;

export function encode(instance: MoveType): EncodedType {
  if (Array.isArray(instance)) {
    return instance.map(e => encode(e));
  }

  return instance.encode();
}

class NumberEncoder {
  constructor(readonly value: number) {}
  encode(): number {
    return this.value;
  }
}

class StringEncoder {
  constructor(readonly value: string) {}
  encode(): string {
    return this.value;
  }
}

export class AsciiType extends StringEncoder {
  encode(): string {
    return asciiToHex(this.value);
  }
}

export class AddressType extends StringEncoder {}
export class HexType extends StringEncoder {} // Hex encoded bytes
export class U64Type extends StringEncoder {} // Must be string to keep precision
export class U8Type extends NumberEncoder {}

export function Address(value: string): AddressType {
  return new AddressType(value);
}

export function Ascii(value: string): AsciiType {
  return new AsciiType(value);
}

export function Hex(value: string): HexType {
  return new HexType(value);
}

export function U64(value: string): U64Type {
  return new U64Type(value);
}

export function U8(value: number): U8Type {
  if (value < 0) {
    throw 'cannot be a negative, or signed, integer'
  }
  return new U8Type(value);
}

const textEncoder = new util.TextEncoder();
export function asciiToHex(input: string): string {
  return bufferToHex(textEncoder.encode(input));
}

function bufferToHex(buffer: any): string {
  return [...new Uint8Array(buffer)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
