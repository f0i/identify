import Bench "mo:bench";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import HashTree "../src/backend/HashTree";
import CertTree "mo:ic-certification/CertTree";

module {
  type HashTree = HashTree.HashTree;

  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("HashTree implementations");
    bench.description("Add signatures to the sig-tree and calculate root hash");

    bench.rows(["f0i:identify", "ic-certification"]);
    bench.cols(["1", "100", "10000"]);

    let time : Time.Time = 123456789_000_000_000;

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Debug.trap("Cols must only contain numbers: " # col);

        if (row == "f0i:identify") {
          var tree : HashTree = #Empty;
          for (i in Iter.range(1, n)) {
            let seed = Text.encodeUtf8("test" # Nat.toText(i));
            let hash : [Nat8] = [1, 2, 3, 4];
            tree := HashTree.addSig(tree, seed, hash, time + i);
          };
          assert HashTree.hash(tree) != [];
        };

        if (row == "ic-certification") {
          let cert_store : CertTree.Store = CertTree.newStore();
          for (i in Iter.range(1, n)) {
            let seed = Text.encodeUtf8("test" # Nat.toText(i));
            let hash : [Nat8] = [1, 2, 3, 4];
          };
        };

      }
    );

    bench;
  };

};
