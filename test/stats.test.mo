import { print; trap } "mo:base/Debug";
import Array "mo:base/Array";
import Map "mo:map/Map";
import Stats "../src/backend/Stats";

print("# Stats");

let stats : Stats.Stats = {
  counter = Map.new();
  log = Array.init(10, "");
  var logIndex = 0;
  var lastBalance = 123;
  var lastFn = "none";
  costs = Map.new();
};

print("- empty log");

if (Stats.logEntries(stats).next() != null) trap("entries should not contain elements");

print("- log with entries");

Stats.log(stats, "Test1");
Stats.log(stats, "Test2");
Stats.log(stats, "Test3");
let iter = Stats.logEntries(stats);
switch (iter.next()) {
  case (?"1970-01-01 00:00:00 Test1") {};
  case (x) trap("first element is unexpected: " # debug_show x);
};
switch (iter.next()) {
  case (?"1970-01-01 00:00:00 Test2") {};
  case (x) trap("first element is unexpected: " # debug_show x);
};
switch (iter.next()) {
  case (?"1970-01-01 00:00:00 Test3") {};
  case (x) trap("first element is unexpected: " # debug_show x);
};
switch (iter.next()) {
  case (null) {};
  case (x) trap("first element is unexpected: " # debug_show x);
};

print("- format precentages");
assert Stats.formatPercent(0.1234) == "12.3%";
assert Stats.formatPercent(0.01234) == "1.23%";
assert Stats.formatPercent(0.001234) == "0.123%";
assert Stats.formatPercent(0.0001234) == "1.23e-02%";
assert Stats.formatPercent(0.00001234) == "1.23e-03%";
