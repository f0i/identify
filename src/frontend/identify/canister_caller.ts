// Several parts copied from NFID-Wallet-Client
import {
  Agent,
  blsVerify,
  CallRequest,
  Cbor,
  Certificate,
  lookupResultToBuffer,
  UpdateCallRejectedError,
} from "@dfinity/agent";
import { AgentError } from "@dfinity/agent/lib/cjs/errors";
import {
  defaultStrategy,
  pollForResponse,
} from "@dfinity/agent/lib/cjs/polling";
import { bufFromBufLike } from "@dfinity/candid";
import { Principal } from "@dfinity/principal";
import { base64decode, base64encode } from "./utils";

(BigInt.prototype as any).toJSON = function () {
  return this.toString();
};

export interface CallCanisterRequest {
  canisterId: string;
  calledMethodName: string;
  parameters: string;
  agent: Agent;
}

export interface CallCanisterResponse {
  contentMap: string;
  certificate: string;
}

export const canister_call = async (
  request: CallCanisterRequest,
): Promise<CallCanisterResponse> => {
  try {
    console.log("canister_call request:", request);
    const response = await poll(
      request.canisterId,
      request.calledMethodName,
      request.agent,
      base64decode(request.parameters),
    );
    console.log("canister_call response:", response);

    const certificate: string = base64encode(response.certificate);
    const cborContentMap = Cbor.encode(response.contentMap);
    const contentMap: string = base64encode(new Uint8Array(cborContentMap));

    return {
      certificate,
      contentMap,
    };
  } catch (error) {
    console.error(error);
    throw (error as Error).message;
  }
};

const poll = async (
  canisterId: string,
  methodName: string,
  agent: Agent,
  arg: ArrayBuffer,
): Promise<{
  certificate: Uint8Array;
  contentMap: CallRequest | undefined;
}> => {
  const cid = Principal.from(canisterId);

  if (agent.rootKey == null)
    throw new AgentError("Agent root key not initialized before making call");

  console.log("Calling canister", cid.toText(), methodName, arg);
  const { requestId, response, requestDetails } = await agent.call(cid, {
    methodName,
    arg,
    effectiveCanisterId: cid,
  });
  console.log("Call canister response", requestId, response, requestDetails);

  let certificate: Certificate | undefined;

  if (response.body && response.body.certificate) {
    const cert = response.body.certificate;
    certificate = await Certificate.create({
      certificate: bufFromBufLike(cert),
      rootKey: agent.rootKey,
      canisterId: Principal.from(canisterId),
    });
    const path = [new TextEncoder().encode("request_status"), requestId];
    const status = new TextDecoder().decode(
      lookupResultToBuffer(certificate.lookup([...path, "status"])),
    );

    switch (status) {
      case "replied":
        break;
      case "rejected": {
        // Find rejection details in the certificate
        throw new UpdateCallRejectedError(cid, methodName, requestId, response);
      }
    }
  } else if (response.body && "reject_message" in response.body) {
    // handle v2 response errors by throwing an UpdateCallRejectedError object
    throw new UpdateCallRejectedError(cid, methodName, requestId, response);
  }

  // Fall back to polling if we receive an Accepted response code
  if (response.status === 202) {
    const pollStrategy = defaultStrategy();
    // Contains the certificate and the reply from the boundary node
    const response = await pollForResponse(
      agent,
      cid,
      requestId,
      pollStrategy,
      undefined,
      blsVerify,
    );
    certificate = response.certificate;
  }

  return {
    contentMap: requestDetails,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    certificate: new Uint8Array(Cbor.encode((certificate as any).cert)),
  };
};
