export const setText = (id: string, text: string) => {
  const el = document.getElementById(id);
  if (el) {
    el.innerText = text;
  } else {
    console.error(
      "setText did not find element",
      id,
      "to set inner text to",
      text,
    );
  }
};
