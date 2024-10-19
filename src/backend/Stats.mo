import Map "mo:map/Map";
import { thash } "mo:map/Map";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";
import TimeFormat "TimeFormat";

module {

  type Map<K, V> = Map.Map<K, V>;

  public type Stats = {
    counter : Map<Text, Map<Text, Nat>>;
    log : [var Text];
    var logIndex : Nat;
  };

  public func new(logSize : Nat) : Stats = {
    counter = Map.new();
    log = Array.init(logSize, "");
    var logIndex = 0;
  };

  public func inc(stats : Stats, category : Text, sub : Text) {
    let cat = switch (Map.get(stats.counter, thash, category)) {
      case (?data) data;
      case (null) {
        let data = Map.new<Text, Nat>();
        Map.set(stats.counter, thash, category, data);
        data;
      };
    };
    ignore Map.update<Text, Nat>(cat, thash, sub, func(_, x) = switch (x) { case (?v) ?(v + 1); case (null) ?1 });
  };
  public type CounterEntry = {
    category : Text;
    sub : Text;
    counter : Nat;
  };
  public func counterEntries(stats : Stats) : [CounterEntry] {
    let out = Buffer.Buffer<CounterEntry>(10);
    for ((category, val) in Map.entries(stats.counter)) {
      for ((sub, counter) in Map.entries(val)) {
        out.add({ category; sub; counter });
      };
    };
    return Buffer.toArray(out);
  };

  public func log(stats : Stats, msg : Text) {
    let prefix = TimeFormat.toText(Time.now()) # " ";
    stats.log[stats.logIndex % stats.log.size()] := prefix # msg;
    stats.logIndex += 1;
  };

  public func getSubCount(stats : Stats, category : Text) : Nat {
    switch (Map.get(stats.counter, thash, category)) {
      case (?data) return Map.size(data);
      case (null) return 0;
    };
  };

  public func logEntries(stats : Stats) : Iter.Iter<Text> {
    let size = stats.log.size();
    var index = 0;

    return {
      next = func() : ?Text {
        if (index + size < stats.logIndex) {
          // skip ahead to the first available entry
          index := stats.logIndex - size;
        };
        if (index < stats.logIndex) {
          let val = stats.log[index % size];
          index += 1;
          return ?val;
        } else {
          return null;
        };
      };
    };
  };

};
