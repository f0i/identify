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

export const showElement = (id: string, show: boolean) => {
  const el = document.getElementById(id);
  if (el) {
    el.style.display = show ? "block" : "none";
  } else {
    console.error(
      "showElement() did not find DOM element",
      id,
      "to",
      show ? "show" : "hide",
    );
  }
};
