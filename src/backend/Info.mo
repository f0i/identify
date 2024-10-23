import Float "mo:base/Float";
import Cycles "mo:base/ExperimentalCycles";
import IC "mo:base/ExperimentalInternetComputer";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";

module {
  let MAX_INSTRUCTIONS : Float = 20_000_000_000;

  public func cycleBalance(start : Nat) : Text {
    let balance = Cycles.balance();
    let diff = if (start != 0) start : Int - balance else 0;
    let current = formatNat(balance, "C");
    let diffText = formatNat(Int.abs(diff), "C");
    let perf1 = Float.fromInt(Nat64.toNat(IC.performanceCounter(1)));
    let perfC1 = Nat64.toText(IC.performanceCounter(1));
    let usage = formatPercent(perf1 / MAX_INSTRUCTIONS); // percentage of maximum instruction per request
    let cost = Float.format(#fix 5, perf1 * 0.000000000000536) # "$"; // $ per instruction https://link.medium.com/zjNeJd73sNb
    "Current balance " # current # " (call cost: " # diffText # ", useage " # usage # " ~" # cost # " perfC1 " # perfC1 # ")";
  };

  public func formatNat(val : Nat, unit : Text) : Text {
    if (val < 1_000) {
      Nat.toText(val) # " " # unit;
    } else if (val < 1_000_000) {
      Float.format(#fix 3, Float.fromInt(val) / 1_000) # " k" # unit;
    } else if (val < 1_000_000_000) {
      Float.format(#fix 3, Float.fromInt(val) / 1_000_000) # " M" #unit;
    } else {
      Float.format(#fix 3, Float.fromInt(val) / 1_000_000_000) # " T" #unit;
    };
  };

  public func formatPercent(val: Float) : Text {
    if(val >= 0.05) {
      Float.format(#fix 1, val * 100) # "%";
    }else if(val >= 0.005) {
      Float.format(#fix 2, val * 10) # "‰";
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
