export const setText = (id: string, text: string) => {
  const el = document.getElementById(id);
  if (el) {
    el.innerText = text;
  } else {
    console.error(
      "setText() did not find DOM element",
      id,
      "to set inner text to",
      text,
    );
  }
};

export const showElement = (idOrEl: string | HTMLElement, show: boolean) => {
  let el: HTMLElement | null;
  if (typeof idOrEl === "string") {
    el = document.getElementById(idOrEl);
  } else {
    el = idOrEl;
  }
  if (el) {
    if (show) {
      el.classList.remove("hidden");
    } else {
      el.classList.add("hidden");
    }
  } else if (typeof idOrEl === "string" && idOrEl !== "" && idOrEl !== "authorize" && idOrEl !== "user-card") {
    console.error(
      "showElement() did not find DOM element",
      idOrEl,
      "to",
      show ? "show" : "hide",
    );
  }
};
