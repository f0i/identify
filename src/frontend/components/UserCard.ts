import template from "./UserCard.html";
import { showElement } from "../identify/dom";

export interface UserData {
  avatar_url?: string[];
  name?: string[];
  email?: string[];
  id?: string;
  principal?: string;
  [key: string]: any;
}

interface UserCardProps {
  user: UserData;
}

export function createUserCard({ user }: UserCardProps): HTMLElement {
  // Inject styles if not already present
  if (!document.querySelector('style[data-component="user-card"]')) {
    const styleElement = document.createElement('style');
    styleElement.setAttribute('data-component', 'user-card');
    // Extract styles from template
    const styleMatch = template.match(/<style>([\s\S]*?)<\/style>/);
    if (styleMatch) {
      styleElement.textContent = styleMatch[1];
      document.head.appendChild(styleElement);
    }
  }

  const templateElement = document.createElement("template");
  templateElement.innerHTML = template.replace(/<style>[\s\S]*?<\/style>/, ''); // Remove style from template
  const userCard = templateElement.content.querySelector("#user-card") as HTMLElement;

  const userIcon = userCard.querySelector("#user-icon") as HTMLImageElement;
  const userName = userCard.querySelector("#user-name") as HTMLElement;
  const userEmail = userCard.querySelector("#user-email") as HTMLElement;
  const userId = userCard.querySelector("#user-id") as HTMLElement;
  const userPrincipal = userCard.querySelector("#user-principal") as HTMLElement;
  const additionalUserInfoDiv = userCard.querySelector(
    "#additional-user-info",
  ) as HTMLElement;

  if (user.avatar_url && user.avatar_url.length > 0) {
    userIcon.src = user.avatar_url[0] ?? "";
    showElement(userIcon, true);
  } else {
    showElement(userIcon, false);
  }

  if (user.name && user.name.length > 0) {
    userName.innerText = user.name[0] ?? "";
    showElement(userName, true);
  } else {
    showElement(userName, false);
  }

  if (user.email && user.email.length > 0) {
    userEmail.innerText = user.email[0] ?? "";
    showElement(userEmail, true);
  } else {
    showElement(userEmail, false);
  }

  if (user.id) {
    userId.innerText = `User ID: ${user.id}`;
    showElement(userId, true);
  } else {
    showElement(userId, false);
  }

  if (user.principal) {
    userPrincipal.innerText = `Principal: ${user.principal}`;
    showElement(userPrincipal, true);
  } else {
    showElement(userPrincipal, false);
  }

  additionalUserInfoDiv.innerHTML = ""; // Clear previous content

  const excludedKeys = [
    "id",
    "avatar_url",
    "name",
    "email",
    "createdAt",
    "origin",
    "principal",
  ];

  for (const key in user) {
    if (user.hasOwnProperty(key) && !excludedKeys.includes(key)) {
      let value = user[key];
      let displayValue = "";
      let shouldDisplay = true;

      if (Array.isArray(value)) {
        if (value.length > 0) {
          displayValue = value[0];
        } else {
          shouldDisplay = false;
        }
      } else if (typeof value === "object" && value !== null) {
        if (key === "provider") {
          const providerName = Object.keys(value)[0];
          if (providerName) {
            displayValue = providerName;
          } else {
            shouldDisplay = false;
          }
        } else {
          displayValue = JSON.stringify(value);
        }
      } else {
        displayValue = value;
      }

      if (
        shouldDisplay &&
        displayValue !== "N/A" &&
        displayValue !== "" &&
        displayValue !== "null" &&
        displayValue !== "undefined"
      ) {
        const p = document.createElement("p");
        p.style.margin = "5px 0";
        p.style.fontSize = "0.85em";
        p.style.color = "#777";

        let displayKey = key.replace(/_/g, " ");
        displayKey = displayKey
          .split(" ")
          .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
          .join(" ");

        if (displayKey === "Provider Created At") {
          displayKey = "Created At";
        }

        p.innerHTML = `<strong>${displayKey}:</strong> ${displayValue}`;
        additionalUserInfoDiv.appendChild(p);
      }
    }
  }

  return userCard;
}
