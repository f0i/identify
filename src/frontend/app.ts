export {};

declare global {
  interface Window {
    google: any;
  }
}

window.onload = () => {
  console.log("onload");
  window.google.accounts.id.initialize({
    client_id:
      "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com",
    callback: handleCredentialResponse,
  });

  window.google.accounts.id.renderButton(
    document.getElementById("g_id_signin") as HTMLElement,
    { theme: "outline", size: "large" },
  );

  window.google.accounts.id.prompt();
};

function handleCredentialResponse(response: any) {
  const idToken = response.credential;
  console.log(response);

  // Send the token to the server for verification
  if (false) {
    fetch("/api/verify-token", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ token: idToken }),
    })
      .then((res) => res.json())
      .then((data) => {
        console.log("Server response:", data);
        if (data.success) {
          console.log("Login successful!");
        } else {
          console.log("Login failed!");
        }
      })
      .catch((error) => {
        console.error("Error:", error);
      });
  }
}
