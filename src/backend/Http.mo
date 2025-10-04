import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Runtime "mo:core/Runtime";
import Option "mo:core/Option";
import IC "ic:aaaaa-aa";
import RSA "RSA";

module {
  type Timestamp = Nat64;

  public func transformKeys({ context; response } : TransformArgs) : IC.http_request_result {
    ignore context;
    let ?content = Text.decodeUtf8(response.body) else Debug.trap("Invalid response body");

    let keys = switch (RSA.pubKeysFromJSON(content)) {
      case (#err err) Runtime.trap("Http transformBody failes: " # err);
      case (#ok data) data;
    };

    Debug.print("parsed keys from: " # content);

    let body = RSA.serializeKeys(keys);
    Debug.print("parsed keys to:   " # body);

    return {
      status = response.status;
      body = Text.encodeUtf8(body);
      headers = [];
    };
  };

  public func transform({ context; response } : TransformArgs) : IC.http_request_result {
    ignore context;
    return { response with headers = [] };
  };

  public type TransformArgs = {
    context : Blob;
    response : IC.http_request_result;
  };
  public type TransformResult = IC.http_request_result;
  public type TransformFn = shared query TransformArgs -> async TransformResult;

  public type Request = IC.http_request_args;

  public func getRequest(url : Text, headers : [Header], maxBytes : Nat64, transform : TransformFn, replicated : Bool) : async* {
    data : Text;
    cost : Nat;
    expectedCost : Nat;
  } {

    let transform_context = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : Request = {
      url = url;
      max_response_bytes = ?maxBytes;
      headers;
      body = null;
      method = #get;
      transform = ?transform_context;
      is_replicated = ?replicated;
    };

    let maxCost = 400_000 /* base cost */ + Nat64.toNat(maxBytes) * 100_000 /* cost per byte */ * 3 /* factor to ensure enough cycles */;

    let balance1 = Cycles.balance();

    try {
      let http_response = await (with cycles = maxCost) IC.http_request(http_request);
      let balance2 = Cycles.balance();

      let response_body : Blob = http_response.body;
      let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
        case (null) { "No value returned" };
        case (?y) { y };
      };

      //6. RETURN RESPONSE OF THE BODY
      return {
        data = decoded_text;
        cost = balance1 - balance2;
        expectedCost = maxCost;
      };

    } catch (err) {
      Debug.trap("http outcall error: " # Error.message(err));
    };
  };

  public type Header = IC.http_header; // {name: Text; value: Text}

  /// Perform a post request
  /// WARNING!: The post request is not replicated, and therefore could be manipulated by the node provider!
  public func postRequest(url : Text, body : ?Text, headers : [Header], maxBytes : Nat64, transform : TransformFn) : async* {
    data : Text;
    statusCode : Nat;
  } {

    let transform_context = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : Request = {
      url = url;
      max_response_bytes = ?maxBytes;
      headers;
      body = Option.map(body, Text.encodeUtf8);
      method = #post;
      transform = ?transform_context;
      is_replicated = ?false;
    };

    let maxCost = 400_000 /* base cost */ + Nat64.toNat(maxBytes) * 100_000 /* cost per byte */ * 3 /* factor to ensure enough cycles */;

    try {
      let http_response = await (with cycles = maxCost) IC.http_request(http_request);

      let response_body : Blob = http_response.body;
      let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
        case (null) { "No value returned" };
        case (?y) { y };
      };

      //6. RETURN RESPONSE OF THE BODY
      return {
        data = decoded_text;
        statusCode = http_response.status;
      };

    } catch (err) {
      Debug.trap("http outcall error: " # Error.message(err));
    };
  };

};
