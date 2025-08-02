import Map "mo:core/Map";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Time "mo:core/Time";
import List "mo:core/List";
import TimeFormat "TimeFormat";
import Float "mo:core/Float";
import Cycles "mo:core/Cycles";
import IC "mo:core/InternetComputer";
import Nat "mo:core/Nat";
import Int "mo:core/Int";
import Nat64 "mo:core/Nat64";
import VarArray "mo:core/VarArray";
import Text "mo:core/Text";
import Option "mo:core/Option";

module {

  type Map<K, V> = Map.Map<K, V>;

  public type AttemptTracker = {
    var count : Nat;
    var lastAttempt : Time.Time;
    var lastSuccess : Time.Time;
  };

  public type Stats = {
    counter : Map<Text, Map<Text, Nat>>;
    log : [var Text];
    var logIndex : Nat;
    var lastBalance : Nat;
    var lastFn : Text;
    costs : Map<Text, FnCost>;
  };
  public func newAttemptTracker() : AttemptTracker = {
    var count = 0;
    var lastAttempt : Time.Time = 0;
    var lastSuccess : Time.Time = 0;
  };

  public type FnCost = {
    fn : Text;
    var count : Nat;
    var total : Nat;
    var min : Nat;
    var max : Nat;
    log : [var Nat];
  };

  public func new(logSize : Nat) : Stats = {
    counter = Map.empty();
    log = VarArray.repeat("", logSize);
    var logIndex = 0;
    var lastBalance = Cycles.balance();
    var lastFn = "init";
    costs = Map.empty();
  };

  public func inc(stats : Stats, category : Text, sub : Text) {
    let cat = switch (Map.get(stats.counter, Text.compare, category)) {
      case (?data) data;
      case (null) {
        let data = Map.empty<Text, Nat>();
        Map.add(stats.counter, Text.compare, category, data);
        data;
      };
    };
    let current = Option.get(Map.get(cat, Text.compare, sub), 0);
    Map.add(cat, Text.compare, sub, current + 1);
  };

  public type CounterEntry = {
    category : Text;
    sub : Text;
    counter : Nat;
  };
  public func counterEntries(stats : Stats) : [CounterEntry] {
    let out = List.empty<CounterEntry>();
    for ((category, val) in Map.entries(stats.counter)) {
      for ((sub, counter) in Map.entries(val)) {
        List.add(out, { category; sub; counter });
      };
    };
    return List.toArray(out);
  };

  public func log(stats : Stats, msg : Text) {
    let prefix = TimeFormat.toText(Time.now()) # " ";
    stats.log[stats.logIndex % stats.log.size()] := prefix # msg;
    stats.logIndex += 1;
  };

  /// This should be called at the beginning of every update call to log the balance difference from the last call.
  public func logBalance(stats : Stats, nextFn : Text) {
    let prefix = TimeFormat.toText(Time.now()) # " ";
    let (msg, diff) = cycleBalance(stats.lastBalance);
    stats.log[stats.logIndex % stats.log.size()] := prefix # stats.lastFn # " " # msg;
    stats.logIndex += 1;
    stats.lastBalance := Cycles.balance();
    switch (Map.get(stats.costs, Text.compare, stats.lastFn)) {
      case (?cost) {
        setCost(cost, diff);
      };
      case (null) {
        let cost = {
          fn = stats.lastFn;
          var count = 1;
          var total = diff;
          var min = diff;
          var max = diff;
          log = VarArray.repeat(0, 100);
        } : FnCost;
        cost.log[0] := diff;
        Map.add(stats.costs, Text.compare, stats.lastFn, cost);
      };
    };
    stats.lastFn := nextFn;
  };

  public func getSubCount(stats : Stats, category : Text) : Nat {
    switch (Map.get(stats.counter, Text.compare, category)) {
      case (?data) return Map.size(data);
      case (null) return 0;
    };
  };

  public func getSubSum(stats : Stats, category : Text) : Nat {
    switch (Map.get(stats.counter, Text.compare, category)) {
      case (?data) {
        var acc = 0;
        for (n in Map.values(data)) {
          acc += n;
        };
        return acc;
      };
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

  public func costData(stats : Stats) : [Text] {
    let overview = Iter.toArray(Iter.map(Map.values(stats.costs), describeCost));
    let history = Iter.toArray(Iter.map(Map.values(stats.costs), costHistory));
    Array.tabulate(overview.size() * 2, func(i : Nat) : Text { if (i % 2 == 0) overview[i / 2] else history[i / 2] });
  };

  let MAX_INSTRUCTIONS : Float = 20_000_000_000;

  public func cycleBalance(start : Nat) : (Text, Nat) {
    let balance = Cycles.balance();
    let diff = if (start != 0) start : Int - balance else 0;
    let current = formatNat(balance, "C");
    let diffText = formatNat(Int.abs(diff), "C");
    let msg = "balance " # current # " (call cost: " # diffText # ")";
    (msg, Int.abs(diff));
  };

  public func setCost(cost : FnCost, cycles : Nat) {
    cost.log[cost.count % cost.log.size()] := cycles;
    cost.count += 1;
    cost.total += cycles;
    if (cost.max < cycles) cost.max := cycles;
    if (cost.min > cycles) cost.min := cycles;
  };

  private func describeCost(cost : FnCost) : Text {
    let avg = cost.total / cost.count;
    cost.fn # ": " # formatNat(cost.count, "x") # ", avg: " # formatNat(avg, "C") # ", min: " # formatNat(cost.min, "C") # ", max: " # formatNat(cost.max, "C");
  };

  private func costHistory(cost : FnCost) : Text {
    var out = cost.fn # " cost log:";
    let size = cost.log.size();
    var i = if (cost.count < size) 0 else cost.count - size : Nat;
    while (i < cost.count) {
      out #= " " # formatNat(cost.log[i % size], "C");
      i += 1;
    };
    out;
  };

  public func perf1() : Text {
    let perf1 = Float.fromInt(Nat64.toNat(IC.performanceCounter(1)));
    let perfC1 = Nat64.toText(IC.performanceCounter(1));
    let usage = formatPercent(perf1 / MAX_INSTRUCTIONS); // percentage of maximum instruction per request
    let cost = Float.format(#fix 5, perf1 * 0.000000000000536) # "$"; // $ per instruction https://link.medium.com/zjNeJd73sNb
    "Useage " # usage # " ~" # cost # " perfC1 " # perfC1 # ".";
  };

  public func formatNat(val : Nat, unit : Text) : Text {
    if (val < 1_000) {
      Nat.toText(val) # " " # unit;
    } else if (val < 1_000_000) {
      Float.format(#fix 3, Float.fromInt(val) / 1_000) # " k" # unit;
    } else if (val < 1_000_000_000) {
      Float.format(#fix 3, Float.fromInt(val) / 1_000_000) # " M" #unit;
    } else if (val < 1_000_000_000_000) {
      Float.format(#fix 3, Float.fromInt(val) / 1_000_000_000) # " B" #unit;
    } else {
      Float.format(#fix 3, Float.fromInt(val) / 1_000_000_000_000) # " T" #unit;
    };
  };

  public func formatPercent(val : Float) : Text {
    if (val >= 0.05) {
      Float.format(#fix 1, val * 100) # "%";
    } else if (val >= 0.01) {
      Float.format(#fix 2, val * 100) # "%";
    } else if (val >= 0.001) {
      Float.format(#fix 3, val * 100) # "%";
    } else {
      Float.format(#exp 2, val * 100) # "%";
    };
  };

  public func cycleBalanceStart() : Nat {
    Cycles.balance();
  };

  public func instructionCount() : Nat64 {
    IC.performanceCounter(1);
  };
};
