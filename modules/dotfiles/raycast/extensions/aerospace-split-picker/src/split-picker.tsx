import { Action, ActionPanel, Icon, List, Toast, showToast } from "@raycast/api";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { useEffect, useMemo, useState } from "react";

const execFileAsync = promisify(execFile);
const AEROSPACE_BIN = "/opt/homebrew/bin/aerospace";

type Direction = "left" | "right" | "up" | "down";

type AeroWindow = {
  "window-id": number;
  workspace: string;
  "app-name": string;
  "window-title": string;
};

async function runAero(args: string[]): Promise<string> {
  const { stdout } = await execFileAsync(AEROSPACE_BIN, args);
  return stdout;
}

async function focusedWindowId(): Promise<number | null> {
  const focused = await focusedWindow();
  return focused ? focused["window-id"] : null;
}

async function targetIsInDirection(currentWindowId: number, targetWindowId: number, direction: Direction): Promise<boolean> {
  try {
    await runAero(["focus", "--window-id", String(currentWindowId)]);
    await runAero(["focus", direction]);
    const now = await focusedWindowId();
    await runAero(["focus", "--window-id", String(currentWindowId)]);
    return now === targetWindowId;
  } catch {
    await runAero(["focus", "--window-id", String(currentWindowId)]).catch(() => undefined);
    return false;
  }
}

async function forceTargetDirection(currentWindowId: number, targetWindowId: number, direction: Direction): Promise<boolean> {
  for (let i = 0; i < 6; i++) {
    if (await targetIsInDirection(currentWindowId, targetWindowId, direction)) return true;

    // Try moving target in the requested direction inside the workspace tree.
    try {
      await runAero(["focus", "--window-id", String(targetWindowId)]);
      await runAero(["move", direction]);
    } catch {
      // ignore and try swap fallback
    }

    // Try swapping from current toward the requested direction.
    try {
      await runAero(["focus", "--window-id", String(currentWindowId)]);
      await runAero(["swap", direction]);
    } catch {
      // ignore
    }
  }

  return targetIsInDirection(currentWindowId, targetWindowId, direction);
}

function parseWindowLines(out: string): AeroWindow[] {
  return out
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [id, workspace, appName, ...titleParts] = line.split("|");
      return {
        "window-id": Number(id),
        workspace: workspace ?? "",
        "app-name": appName ?? "App",
        "window-title": titleParts.join("|"),
      } as AeroWindow;
    })
    .filter((w) => Number.isFinite(w["window-id"]));
}

async function listWindowsAll(): Promise<AeroWindow[]> {
  const out = await runAero(["list-windows", "--all", "--format", "%{window-id}|%{workspace}|%{app-name}|%{window-title}"]);
  return parseWindowLines(out);
}

async function focusedWindow(): Promise<AeroWindow | null> {
  const out = await runAero([
    "list-windows",
    "--focused",
    "--format",
    "%{window-id}|%{workspace}|%{app-name}|%{window-title}",
  ]);
  const arr = parseWindowLines(out);
  return arr.length > 0 ? arr[0] : null;
}

async function tryJoinStrict(currentWindowId: number, targetWindowId: number, direction: Direction): Promise<boolean> {
  // Deterministic strategy:
  // 1) enforce orientation on current container
  // 2) join target with a stable direction
  // 3) optional swap to get exact side
  try {
    await runAero(["focus", "--window-id", String(currentWindowId)]);
    if (direction === "left" || direction === "right") {
      await runAero(["layout", "h_tiles"]);
    } else {
      await runAero(["layout", "v_tiles"]);
    }

    await runAero(["join-with", "--window-id", String(targetWindowId), "right"]);
    return forceTargetDirection(currentWindowId, targetWindowId, direction);
  } catch {
    return false;
  }
}

async function splitWindow(targetWindowId: number, direction: Direction): Promise<void> {
  const current = await focusedWindow();
  if (!current) {
    throw new Error("Aucune fenêtre AeroSpace focalisée");
  }

  const currentId = String(current["window-id"]);
  const currentWorkspace = current.workspace;

  try {
    await runAero(["move-node-to-workspace", "--window-id", String(targetWindowId), currentWorkspace]);
  } catch {
    // Ignore no-op when already in same workspace.
  }

  const joined = await tryJoinStrict(Number(currentId), targetWindowId, direction);
  await runAero(["balance-sizes", "--workspace", currentWorkspace]);

  if (!joined) {
    throw new Error("Split impossible dans cette direction");
  }
}

type SplitPickerProps = {
  defaultDirection?: Direction;
  title?: string;
};

export function SplitPicker({ defaultDirection, title }: SplitPickerProps) {
  const [items, setItems] = useState<AeroWindow[]>([]);
  const [focusedId, setFocusedId] = useState<number | null>(null);
  const [focusedLabel, setFocusedLabel] = useState<string>("");
  const [isLoading, setIsLoading] = useState(true);

  async function refresh() {
    try {
      setIsLoading(true);
      const [focused, windows] = await Promise.all([focusedWindow(), listWindowsAll()]);
      setFocusedId(focused ? focused["window-id"] : null);
      setFocusedLabel(focused ? `${focused["app-name"]} (#${focused["window-id"]})` : "");
      setItems(windows);
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Erreur AeroSpace",
        message: error instanceof Error ? error.message : String(error),
      });
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    void refresh();
  }, []);

  const choices = useMemo(() => {
    return items.filter((w) => w["window-id"] !== focusedId);
  }, [items, focusedId]);

  async function onSplit(windowId: number, direction: Direction) {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Split ${direction}...` });
    try {
      await splitWindow(windowId, direction);
      toast.style = Toast.Style.Success;
      toast.title = `Split ${direction} OK`;
      await refresh();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Échec du split";
      toast.message = error instanceof Error ? error.message : String(error);
    }
  }

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder={
        defaultDirection
          ? `Filtrer une fenêtre (direction: ${defaultDirection})...`
          : "Filtrer une fenêtre (app, titre, workspace)..."
      }
      navigationTitle={title ?? "Aero Split Picker"}
    >
      {focusedLabel ? <List.EmptyView title="Aucune autre fenêtre" description={`Fenêtre courante exclue: ${focusedLabel}`} /> : null}
      {choices.map((w) => {
        const id = w["window-id"];
        const title = w["window-title"] || "(sans titre)";
        const subtitle = `[${w.workspace}] ${title}`;
        const primary = defaultDirection ?? "right";

        return (
          <List.Item
            key={id}
            title={w["app-name"]}
            subtitle={subtitle}
            accessories={[{ text: `#${id}` }]}
            icon={Icon.AppWindow}
            actions={
              <ActionPanel>
                <Action title={`Split ${primary[0].toUpperCase()}${primary.slice(1)}`} onAction={() => void onSplit(id, primary)} />
                <ActionPanel.Section>
                  <Action title="Split Right" onAction={() => void onSplit(id, "right")} />
                  <Action title="Split Left" onAction={() => void onSplit(id, "left")} />
                  <Action title="Split Up" onAction={() => void onSplit(id, "up")} />
                  <Action title="Split Down" onAction={() => void onSplit(id, "down")} />
                </ActionPanel.Section>
                <Action title="Refresh" onAction={() => void refresh()} shortcut={{ modifiers: ["cmd"], key: "r" }} />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}

export default function Command() {
  return <SplitPicker />;
}
