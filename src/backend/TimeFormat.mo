import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Time "mo:base/Time";
module {

  // Define constants for time units
  let secondsPerMinute : Nat = 60;
  let secondsPerHour : Nat = 3600;
  let secondsPerDay : Nat = 86400;

  // Number of days in each month, assuming February has 28 days
  let daysInMonth : [Nat] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  // Leap year check
  func isLeapYear(year : Nat) : Bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
  };

  // Calculate the date components from the timestamp (nanoseconds since 1970)
  public func toText(time : Time.Time) : Text {
    assert time > 0;
    let nanoseconds = Int.abs(time);
    var seconds = nanoseconds / 1_000_000_000; // Convert nanoseconds to seconds

    secondsToText(seconds);
  };

  public func secondsToText(unixTimestamp : Nat) : Text {
    var seconds = unixTimestamp;
    // Starting from 1970
    var year : Nat = 1970;

    label yearLoop while true {
      // Account for leap years
      let daysInYear = if (isLeapYear(year)) 366 else 365;
      let secondsInYear = daysInYear * secondsPerDay;

      if (seconds < secondsInYear) break yearLoop; // Stay in the current year

      seconds -= secondsInYear;
      year += 1;
    };

    // Now calculate month and day
    var month : Nat = 0;
    var day : Nat = 0;
    var days = seconds / secondsPerDay;
    seconds %= secondsPerDay; // Remaining seconds in the current day

    // Adjust February days for leap years
    let adjustedDaysInMonth = Array.tabulate<Nat>(
      12,
      func(i : Nat) : Nat {
        if (i == 1 and isLeapYear(year)) {
          // February in a leap year
          return 29;
        } else {
          return daysInMonth[i];
        };
      },
    );

    label monthLoop for (i in Iter.range(0, 11)) {
      if (days < adjustedDaysInMonth[i]) {
        month := i + 1;
        day := days + 1;
        break monthLoop;
      } else {
        days -= adjustedDaysInMonth[i];
      };
    };

    // Calculate the time of day
    let hour = seconds / secondsPerHour;
    seconds %= secondsPerHour;
    let minute = seconds / secondsPerMinute;
    let second = seconds % secondsPerMinute;

    // Format the date as a string: YYYY-MM-DD HH:MM:SS
    return Int.toText(year) # "-" # (if (month < 10) "0" else "") # Int.toText(month)
    # "-" # (if (day < 10) "0" else "") # Int.toText(day)
    # " " # (if (hour < 10) "0" else "") # Int.toText(hour)
    # ":" # (if (minute < 10) "0" else "") # Int.toText(minute)
    # ":" # (if (second < 10) "0" else "") # Int.toText(second);
  };

};
