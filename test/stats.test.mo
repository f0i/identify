import { print; trap } "mo:base/Debug";
import Stats "../src/backend/Stats";

print("# Stats");

let stats = Stats.new(10);

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
