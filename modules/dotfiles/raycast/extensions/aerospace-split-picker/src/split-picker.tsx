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

function oppositeDirection(direction: Direction): Direction {
  switch (direction) {
    case "left":
      return "right";
    case "right":
      return "left";
    case "up":
      return "down";
    case "down":
      return "up";
  }
}

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

async function focusedWorkspace(): Promise<string | null> {
  const out = await runAero(["list-workspaces", "--focused", "--format", "%{workspace}"]);
  const workspace = out.trim();
  return workspace.length > 0 ? workspace : null;
}

async function listWindowsInWorkspace(workspace: string): Promise<AeroWindow[]> {
  const out = await runAero([
    "list-windows",
    "--workspace",
    workspace,
    "--format",
    "%{window-id}|%{workspace}|%{app-name}|%{window-title}",
  ]);
  return parseWindowLines(out);
}

async function pickAnchorWindow(): Promise<AeroWindow | null> {
  const focused = await focusedWindow();
  if (focused && focused["app-name"] !== "Raycast") return focused;

  try {
    const ws = await focusedWorkspace();
    if (!ws) return focused;

    const windows = await listWindowsInWorkspace(ws);
    const anchor = windows.find((w) => w["app-name"] !== "Raycast");
    if (anchor) return anchor;
  } catch {
    // Fallback to the originally focused window when workspace probing fails.
  }

  return focused;
}

async function tryJoinStrict(currentWindowId: number, targetWindowId: number, direction: Direction): Promise<boolean> {
  const opposite = oppositeDirection(direction);
  await runAero(["focus", "--window-id", String(currentWindowId)]);
  if (direction === "left" || direction === "right") {
    await runAero(["layout", "h_tiles"]);
  } else {
    await runAero(["layout", "v_tiles"]);
  }

  if (await targetIsInDirection(currentWindowId, targetWindowId, direction)) return true;

  // Direct positioning strategy: move selected window like drag-and-drop.
  // No post-swap correction.
  for (const moveDirection of [direction, opposite]) {
    for (let i = 0; i < 10; i++) {
      try {
        await runAero(["move", "--window-id", String(targetWindowId), moveDirection]);
      } catch {
        break;
      }
      if (await targetIsInDirection(currentWindowId, targetWindowId, direction)) return true;
    }
  }

  return await targetIsInDirection(currentWindowId, targetWindowId, direction);
}

async function splitWindow(targetWindowId: number, direction: Direction): Promise<void> {
  const current = await pickAnchorWindow();
  if (!current) {
    throw new Error("Aucune fenêtre AeroSpace focalisée");
  }

  const currentId = String(current["window-id"]);
  const currentWorkspace = current.workspace;
  const tempWorkspace = "__aero_tmp_split";

  try {
    await runAero(["move-node-to-workspace", "--window-id", String(targetWindowId), currentWorkspace]);
  } catch {
    // Ignore no-op when already in same workspace.
  }

  // Plan A (fast): direct placement in current tree.
  const quick = await tryJoinStrict(Number(currentId), targetWindowId, direction);
  if (quick) {
    await runAero(["balance-sizes", "--workspace", currentWorkspace]).catch(() => undefined);
    await runAero(["focus", "--window-id", String(currentId)]).catch(() => undefined);
    return;
  }

  // Plan B (reliable): isolate anchor + target, then place, then restore others.
  const windowsInWorkspace = await listWindowsInWorkspace(currentWorkspace);
  const otherWindows = windowsInWorkspace
    .filter((w) => w["window-id"] !== Number(currentId))
    .filter((w) => w["window-id"] !== targetWindowId)
    .filter((w) => w["app-name"] !== "Raycast")
    .map((w) => w["window-id"]);
  try {
    for (const id of otherWindows) {
      await runAero(["move-node-to-workspace", "--window-id", String(id), tempWorkspace]).catch(() => undefined);
    }

    const joined = await tryJoinStrict(Number(currentId), targetWindowId, direction);
    await runAero(["balance-sizes", "--workspace", currentWorkspace]).catch(() => undefined);

    if (!joined) {
      const probes: Direction[] = ["left", "right", "up", "down"];
      let found: Direction | null = null;
      for (const probe of probes) {
        if (await targetIsInDirection(Number(currentId), targetWindowId, probe)) {
          found = probe;
          break;
        }
      }
      const where = found ? `Position détectée: ${found}` : "Position détectée: inconnue";
      throw new Error(`Split impossible dans cette direction. ${where}`);
    }
  } finally {
    for (const id of otherWindows) {
      await runAero(["move-node-to-workspace", "--window-id", String(id), currentWorkspace]).catch(() => undefined);
    }
    await runAero(["balance-sizes", "--workspace", currentWorkspace]).catch(() => undefined);
    await runAero(["focus", "--window-id", String(currentId)]).catch(() => undefined);
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
      const [focused, windows] = await Promise.all([pickAnchorWindow(), listWindowsAll()]);
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
