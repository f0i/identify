import Bench "mo:bench";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import HashTree "../src/backend/HashTree";
import CertTree "mo:ic-certification/CertTree";
import CanisterSigs "mo:ic-certification/CanisterSigs";
import Sha256 "mo:sha2/Sha256";

module {
  type HashTree = HashTree.HashTree;

  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("HashTree implementations");
    bench.description("Add signatures to the sig-tree and calculate root hash");

    bench.rows(["f0i:identify", "ic-certification", "ic-certification:manager"]);
    bench.cols(["1", "3", "10", "100"]);

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
          let ct = CertTree.Ops(cert_store);
          for (i in Iter.range(1, n)) {
            let seed = Text.encodeUtf8("test" # Nat.toText(i));
            let hash : Blob = "1234";
            let seedHash = Sha256.fromBlob(#sha256, seed);
            ct.put(["sig", seedHash, hash], "");
          };
          assert ct.treeHash() != "";
        };

        if (row == "ic-certification:manager") {
          let cert_store : CertTree.Store = CertTree.newStore();
          let ct = CertTree.Ops(cert_store);
          let csm = CanisterSigs.Manager(ct, null);

          for (i in Iter.range(1, n)) {
            let seed = Text.encodeUtf8("test" # Nat.toText(i));
            //let hash : [Nat8] = [1, 2, 3, 4];
            let hash : Blob = "1234";
            csm.prepare(seed, hash);
          };
        };
      }
    );

    bench;
  };

};
