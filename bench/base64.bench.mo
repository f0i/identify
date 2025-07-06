import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Base64 "../src/backend/Base64";
import MopsBase64 "mo:base64";
import BaseXEncoder "mo:base-x-encoder";

module {
  /// Test data that decodes to [0, 1, 2, ..., 255]
  let testData = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w";

  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Base64 implementations");
    bench.description("Decode a base46 string that decodes to [0, 1, 2, ..., 255] n times");

    bench.rows(["f0i:identify", "mops:base-x-encoder", "mops:base64"]);
    bench.cols(["1", "100", "10000"]);

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Debug.trap("Cols must only contain numbers: " # col);

        if (row == "f0i:identify") {
          for (i in Iter.range(1, n)) {
            let data = Base64.decode(testData);
            assert Result.isOk(data);
          };
        };

        if (row == "mops:base-x-encoder") {
          for (i in Iter.range(1, n)) {
            let data = BaseXEncoder.fromBase64(testData);
            assert Result.isOk(data);
          };
        };

        if (row == "mops:base64") {
          let base64 = MopsBase64.Base64(#version(MopsBase64.V2), ?true);
          for (i in Iter.range(1, n)) {
            let data = base64.decode(testData);
            assert data != [];
          };
        };
      }
    );

    bench;
  };
};
