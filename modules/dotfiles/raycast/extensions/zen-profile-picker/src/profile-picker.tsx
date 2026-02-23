import { Action, ActionPanel, Icon, List, Toast, showToast, Color } from "@raycast/api";
import { exec } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

interface Profile {
  id: string;
  name: string;
  flag: string;
  icon: string;
  color?: Color;
  description: string;
}

const PROFILES: Profile[] = [
  {
    id: "professional",
    name: "Professionnal",
    flag: "Professionnal",
    icon: "💼",
    color: Color.Blue,
    description: "Contexte de travail, extensions professionnelles",
  },
  {
    id: "personal",
    name: "Personal",
    flag: "Personal",
    icon: "🧘‍♂️",
    color: Color.Green,
    description: "Navigation privée, réseaux sociaux, loisirs",
  },
  {
    id: "default",
    name: "Default",
    flag: "Default (release)",
    icon: "🌍",
    color: Color.Secondary,
    description: "Profil par défaut (fallback)",
  },
];

const APP_NAME = "Zen";

async function isZenRunning(): Promise<boolean> {
  try {
    const { stdout } = await execAsync(`osascript -e 'application "${APP_NAME}" is running'`);
    return stdout.trim() === "true";
  } catch {
    return false;
  }
}

async function quitZenGracefully(toast: Toast): Promise<void> {
  await execAsync(`osascript -e 'tell application "${APP_NAME}" to quit'`);
  
  // Poll until it's gone, max 5s
  for (let i = 0; i < 50; i++) {
    if (!(await isZenRunning())) return;
    toast.message = `Attente fermeture... (${(i / 10).toFixed(1)}s)`;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Zen met trop de temps à se fermer.");
}

async function switchProfile(profile: Profile) {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: `Switching to ${profile.name}...`,
  });

  try {
    if (await isZenRunning()) {
      toast.title = "Fermeture propre de Zen...";
      await quitZenGracefully(toast);
    }

    toast.title = `Lancement de ${profile.name}...`;
    toast.message = `Profil : ${profile.flag}`;
    
    // Using open -na to ensure a fresh start if needed, but the shell test used open -a
    await execAsync(`open -a "${APP_NAME}" --args -P "${profile.flag}"`);
    
    toast.style = Toast.Style.Success;
    toast.title = `Zen lancé : ${profile.name}`;
    toast.message = "";
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = "Échec du changement";
    toast.message = error instanceof Error ? error.message : String(error);
  }
}

export default function Command() {
  return (
    <List 
      searchBarPlaceholder="Choisir un profil Zen..."
      navigationTitle="Zen Profile Picker"
    >
      {PROFILES.map((profile) => (
        <List.Item
          key={profile.id}
          title={profile.name}
          subtitle={profile.description}
          icon={profile.icon}
          accessories={[{ text: `#${profile.id}` }]}
          actions={
            <ActionPanel>
              <Action
                title={`Passer à ${profile.name}`}
                icon={Icon.Switch}
                onAction={() => switchProfile(profile)}
              />
              <Action.OpenInBrowser
                title="Gérer les profils (about:profiles)"
                url="about:profiles"
                icon={Icon.Gear}
                shortcut={{ modifiers: ["cmd", "ctrl", "opt"], key: "p" }}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
