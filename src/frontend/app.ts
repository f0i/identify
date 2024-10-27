import { initDemo } from "./demo";
import { initICgsi } from "./icgsi";

const GSI_CLIENT_ID =
  "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com";

const IDENTITY_PROVIDER = "https://login.f0i.de";

window.onload = () => {
  console.log("onload: opener:", window.opener);
  if (window.opener) {
    initICgsi(GSI_CLIENT_ID);
  } else {
    initDemo(IDENTITY_PROVIDER);
  }
  document.getElementById("version")!.innerText = process.env.BUILD_TIME!;
  try {
    (window as any).showInfo(document.location.hash.substring(1));
  } catch (e) {
    // ignore
  }
};

(window as any).showInfo = function (sectionId: string) {
  const active = document.getElementById(sectionId)!.style.display === "block";
  // Hide all sections
  document.getElementById("help")!.style.display = "none";
  document.getElementById("security")!.style.display = "none";
  document.getElementById("about")!.style.display = "none";
  // Show the selected section
  document.getElementById("info")!.style.display = "block";
  document.getElementById(sectionId)!.style.display = active ? "none" : "block";
};
