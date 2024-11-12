import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Char "mo:base/Char";
import Iter "mo:base/Iter";

module {
  type Timestamp = Nat64;

  //1. Type that describes the Request arguments for an HTTPS outcall
  //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
  type HttpRequestArgs = {
    url : Text;
    max_response_bytes : ?Nat64;
    headers : [HttpHeader];
    body : ?[Nat8];
    method : HttpMethod;
    transform : ?TransformRawResponseFunction;
  };

  type HttpHeader = {
    name : Text;
    value : Text;
  };

  type HttpMethod = {
    #get;
    #post;
    #head;
  };

  public type HttpResponsePayload = {
    status : Nat;
    headers : [HttpHeader];
    body : [Nat8];
  };

  //2. HTTPS outcalls have an optional "transform" key. These two types help describe it.
  //"The transform function may, for example, transform the body in any way, add or remove headers,
  //modify headers, etc. "
  //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request

  //2.1 This type describes a function called "TransformRawResponse" used in line 14 above
  //"If provided, the calling canister itself must export this function."
  //In this minimal example for a `GET` request, we declare the type for completeness, but
  //we do not use this function. We will pass "null" to the HTTP request.
  type TransformRawResponseFunction = {
    function : shared query TransformArgs -> async HttpResponsePayload;
    context : Blob;
  };

  //2.2 These type describes the arguments the transform function needs
  public type TransformArgs = {
    response : HttpResponsePayload;
    context : Blob;
  };

  public type CanisterHttpResponsePayload = {
    status : Nat;
    headers : [HttpHeader];
    body : [Nat8];
  };

  type TransformContext = {
    function : shared query TransformArgs -> async HttpResponsePayload;
    context : Blob;
  };

  //3. Declaring the IC management canister which we use to make the HTTPS outcall
  type IC = actor {
    http_request : HttpRequestArgs -> async HttpResponsePayload;
  };

  public func transform(raw : TransformArgs) : CanisterHttpResponsePayload {
    // TODO: assert body start with "{\n  \"keys\": [\n"
    let ?content = Text.decodeUtf8(Blob.fromArray(raw.response.body)) else Debug.trap("Invalid response body");

    let lines = Text.split(content, #char '\n');
    var buffer = Array.init<Text>(6, "");
    var keys = Array.init<Text>(7, "");
    var keyIndex = 0;
    var lineNo = 0;
    label lineLoop for (line in lines) {
      lineNo += 1;
      var entry = Text.trim(line, #predicate(Char.isWhitespace));
      if (lineNo == 1) {
        if (entry != "{") Debug.trap("Invalid response line 1");
      } else if (lineNo == 2) {
        if (entry != "\"keys\": [") Debug.trap("Invalid response line 2");
      } else if (Text.startsWith(entry, #text "\"e\": ")) {
        buffer[0] := entry;
      } else if (Text.startsWith(entry, #text "\"n\": ")) {
        buffer[1] := entry;
      } else if (Text.startsWith(entry, #text "\"kid\": ")) {
        buffer[2] := entry;
      } else if (Text.startsWith(entry, #text "\"use\": ")) {
        buffer[3] := entry;
      } else if (Text.startsWith(entry, #text "\"alg\": ")) {
        buffer[4] := entry;
      } else if (Text.startsWith(entry, #text "\"kty\": ")) {
        buffer[5] := entry;
      } else if (Text.startsWith(entry, #text "}")) {
        keys[keyIndex] := Text.join("\n", buffer.vals());
      } else if (Text.startsWith(entry, #text "]")) {
        keys[keyIndex] := "{" # Text.join("\n", buffer.vals()) # "}";
        keyIndex += 1;
        if (keyIndex >= keys.size()) break lineLoop;
      };
    };

    let body = "{ \"keys\": [\n" # Text.join(",", Iter.map(Iter.range(0, keyIndex - 1), func(i : Nat) : Text = keys[i])) # "]}";

    return {
      status = raw.response.status;
      body = Blob.toArray(Text.encodeUtf8(body));
      headers = [];
    };
  };

  public func getRequest(url : Text, maxBytes : Nat64, transform : shared query TransformArgs -> async HttpResponsePayload) : async {
    data : Text;
    cost : Nat;
    expectedCost : Nat;
  } {

    //1. DECLARE IC MANAGEMENT CANISTER
    //We need this so we can use it to make the HTTP request
    let ic : IC = actor ("aaaaa-aa");

    //2. SETUP ARGUMENTS FOR HTTP GET request

    // 2.1 Setup the URL and its query parameters
    ignore url;

    // 2.2 prepare headers for the system http_request call
    let request_headers = [];

    // 2.2.1 Transform context
    let transform_context : TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // 2.3 The HTTP request
    let http_request : HttpRequestArgs = {
      url = url;
      max_response_bytes = ?maxBytes;
      headers = request_headers;
      body = null;
      method = #get;
      transform = ?transform_context;
    };

    //3. ADD CYCLES TO PAY FOR HTTP REQUEST

    //The IC specification spec says, "Cycles to pay for the call must be explicitly transferred with the call"
    //IC management canister will make the HTTP request so it needs cycles
    //See: https://internetcomputer.org/docs/current/motoko/main/cycles

    //The way Cycles.add() works is that it adds those cycles to the next asynchronous call
    //"Function add(amount) indicates the additional amount of cycles to be transferred in the next remote call"
    //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
    let maxCost = 400_000 /* base cost */ + Nat64.toNat(maxBytes) * 100_000 /* cost per byte */ * 3 /* factor to ensure enough cycles */;

    let balance1 = Cycles.balance();

    //4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
    //Since the cycles were added above, we can just call the IC management canister with HTTPS outcalls below
    try {
      Cycles.add<system>(maxCost);
      let http_response : HttpResponsePayload = await ic.http_request(http_request);
      let balance2 = Cycles.balance();

      //5. DECODE THE RESPONSE

      //As per the type declarations, the BODY in the HTTP response
      //comes back as [Nat8s] (e.g. [2, 5, 12, 11, 23]). Type signature:

      //public type HttpResponsePayload = {
      //     status : Nat;
      //     headers : [HttpHeader];
      //     body : [Nat8];
      // };

      //We need to decode that [Nat8] array that is the body into readable text.
      //To do this, we:
      //  1. Convert the [Nat8] into a Blob
      //  2. Use Blob.decodeUtf8() method to convert the Blob to a ?Text optional
      //  3. We use a switch to explicitly call out both cases of decoding the Blob into ?Text
      let response_body : Blob = Blob.fromArray(http_response.body);
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
