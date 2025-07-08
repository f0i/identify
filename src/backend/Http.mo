import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import IC "ic:aaaaa-aa";
import GoogleCert "certs/GoogleCert";

module {
  type Timestamp = Nat64;

  public func transform({ context; response } : TransformArgs, ignoreKey : GoogleCert.IgnoreKey) : IC.http_request_result {
    ignore context;
    let ?content = Text.decodeUtf8(response.body) else Debug.trap("Invalid response body");

    let body = GoogleCert.transformBody(content, ignoreKey);

    return {
      status = response.status;
      body = Text.encodeUtf8(body);
      headers = [];
    };
  };

  public type TransformArgs = {
    context : Blob;
    response : IC.http_request_result;
  };
  public type TransformResult = IC.http_request_result;
  type TransformFn = shared query TransformArgs -> async TransformResult;

  public func getRequest(url : Text, maxBytes : Nat64, transform : TransformFn) : async {
    data : Text;
    cost : Nat;
    expectedCost : Nat;
  } {

    let request_headers = [];

    let transform_context = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : IC.http_request_args = {
      url = url;
      max_response_bytes = ?maxBytes;
      headers = request_headers;
      body = null;
      method = #get;
      transform = ?transform_context;
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

};
