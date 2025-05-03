import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Base64 "../src/backend/Base64";
import MopsBase64 "mo:base64";
import BaseXEncoder "mo:base-x-encoder";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Base64 implementations");
    bench.description("Decode base46 strings");

    bench.rows(["f0i:identify", "mops:base-x-encoder", "mops:base64"]);
    bench.cols(["1", "100", "10000"]);

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col);

        // Vector
        if (row == "f0i:identify") {
          for (i in Iter.range(1, n)) {
            let data = Base64.decodeText(testData);
            ignore data;
          };
        };

        // Buffer
        if (row == "mops:base-x-encoder") {
          for (i in Iter.range(1, n)) {
            let data = BaseXEncoder.fromBase64(testData);
            ignore data;
          };
        };

        if (row == "mops:base64") {
          let base64 = MopsBase64.Base64(#version(MopsBase64.V2), ?true);
          for (i in Iter.range(1, n)) {
            ignore base64.decode(testData);
          };
        };
      }
    );

    bench;
  };

  let testData = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w";
};
