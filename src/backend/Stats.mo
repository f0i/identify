import Map "mo:map/Map";
import { thash } "mo:map/Map";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import TimeFormat "TimeFormat";
import Float "mo:base/Float";
import Cycles "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalInternetComputer";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";

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
    counter = Map.new();
    log = Array.init(logSize, "");
    var logIndex = 0;
    var lastBalance = Cycles.balance();
    var lastFn = "init";
    costs = Map.new();
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

  /// This should be called at the beginning of every update call to log the balance difference from the last call.
  public func logBalance(stats : Stats, nextFn : Text) {
    let prefix = TimeFormat.toText(Time.now()) # " ";
    let (msg, diff) = cycleBalance(stats.lastBalance);
    stats.log[stats.logIndex % stats.log.size()] := prefix # stats.lastFn # " " # msg;
    stats.logIndex += 1;
    stats.lastBalance := Cycles.balance();
    switch (Map.get(stats.costs, thash, stats.lastFn)) {
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
          log = Array.init(100, 0);
        } : FnCost;
        cost.log[0] := diff;
        Map.set(stats.costs, thash, stats.lastFn, cost);
      };
    };
    stats.lastFn := nextFn;
  };

  public func getSubCount(stats : Stats, category : Text) : Nat {
    switch (Map.get(stats.counter, thash, category)) {
      case (?data) return Map.size(data);
      case (null) return 0;
    };
  };

  public func getSubSum(stats : Stats, category : Text) : Nat {
    switch (Map.get(stats.counter, thash, category)) {
      case (?data) {
        var acc = 0;
        for (n in Map.vals(data)) {
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
    let overview = Iter.toArray(Iter.map(Map.vals(stats.costs), describeCost));
    let history = Iter.toArray(Iter.map(Map.vals(stats.costs), costHistory));
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
