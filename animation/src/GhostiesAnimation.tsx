import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
} from "remotion";
import { Ghost } from "./components/Ghost";
import { ghosts } from "./data/ghosts";

const GHOST_SCALE = 2.5;
const GHOST_SIZE = 48 * GHOST_SCALE; // 120px
const GHOST_GAP = 16;

const GITHUB_URL = "https://github.com/SeanSmithDesign/ghostties";

// Pyramid layout — matches Paper design
// Row 0: 1 ghost (blinky)
// Row 1: 2 ghosts (specter, inky)
// Row 2: 3 ghosts (pinky, clyde, banshee)
// Row 3: 2 ghosts (chill, dusk)
const PYRAMID = [
  { ghost: ghosts[0], row: 0, col: 0, colsInRow: 1 },  // blinky — red
  { ghost: ghosts[4], row: 1, col: 0, colsInRow: 2 },  // specter — purple
  { ghost: ghosts[2], row: 1, col: 1, colsInRow: 2 },  // inky — cyan
  { ghost: ghosts[1], row: 2, col: 0, colsInRow: 3 },  // pinky — pink
  { ghost: ghosts[3], row: 2, col: 1, colsInRow: 3 },  // clyde — orange
  { ghost: ghosts[10], row: 2, col: 2, colsInRow: 3 }, // banshee — yellow
  { ghost: ghosts[17], row: 3, col: 0, colsInRow: 2 }, // chill — light blue
  { ghost: ghosts[23], row: 3, col: 1, colsInRow: 2 }, // dusk — indigo
];

const ROW_HEIGHT = GHOST_SIZE + GHOST_GAP;

// At 12fps, each frame is ~83ms. Type one char every 2 frames by default.
const typeText = (text: string, frame: number, startFrame: number, speed = 2) => {
  const progress = Math.max(0, frame - startFrame);
  const chars = Math.min(Math.floor(progress / speed), text.length);
  return { visible: text.slice(0, chars), done: chars >= text.length };
};

// Compute X position for a ghost in its row, centered on screen
const ghostX = (col: number, colsInRow: number, centerX: number) => {
  const rowWidth = colsInRow * GHOST_SIZE + (colsInRow - 1) * GHOST_GAP;
  const rowLeft = centerX - rowWidth / 2;
  return rowLeft + col * (GHOST_SIZE + GHOST_GAP);
};

export const GhostiesAnimation: React.FC = () => {
  const frame = useCurrentFrame(); // no onTwos needed at 12fps
  const { fps, width, height } = useVideoConfig();

  const centerX = width / 2;

  // --- TIMING (all values halved from 30fps, roughly) ---
  const SCOUT_ENTER = 0;
  const CMD_START = 20;
  const CREW_ENTER = 48;
  const INSTALL_START = 76;
  const LINK_START = 96;
  const FADE_START = 136;

  // Pyramid vertical start — centered between top and text area
  const totalPyramidHeight = 4 * ROW_HEIGHT - GHOST_GAP;
  const textAreaHeight = 250;
  const availableHeight = height - textAreaHeight;
  const pyramidTop = (availableHeight - totalPyramidHeight) / 2 + 20;

  // Terminal text — bottom area
  const textLeft = 72;
  const textBottom = 80;

  // --- FADE OUT ---
  const globalOpacity = interpolate(frame, [FADE_START, 152], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // --- CURSOR ---
  const cursorBlink = Math.floor(frame / 6) % 2 === 0;
  const cursorEl = (
    <span style={{ color: "#e0e0e0", opacity: cursorBlink ? 1 : 0 }}>_</span>
  );

  // --- TERMINAL LINES ---
  const cmd = typeText("cd ~/ghostties", frame, CMD_START, 2);
  const showCmd = frame >= CMD_START;

  const install = typeText("ghostties % install soon", frame, INSTALL_START, 2);
  const showInstall = frame >= INSTALL_START;

  const link = typeText(GITHUB_URL, frame, LINK_START, 1);
  const showLink = frame >= LINK_START;

  const cursorLine =
    showLink && !link.done ? 3 :
    showInstall && !install.done ? 2 :
    showCmd && !cmd.done ? 1 : 0;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: "#1a1a2e",
        overflow: "hidden",
      }}
    >
      <div style={{ opacity: globalOpacity, width: "100%", height: "100%" }}>
        {/* Ghost pyramid */}
        {PYRAMID.map(({ ghost, row, col, colsInRow }, i) => {
          const isScout = i === 0;
          const delay = isScout ? SCOUT_ENTER : CREW_ENTER + (i - 1) * 3;

          const sp = spring({
            frame: frame - delay,
            fps,
            config: {
              damping: isScout ? 14 : 12,
              stiffness: isScout ? 100 : 110,
              mass: isScout ? 0.8 : 0.7,
            },
          });

          const targetX = ghostX(col, colsInRow, centerX);
          const targetY = pyramidTop + row * ROW_HEIGHT;

          // Enter from alternating sides
          const offscreen = width + GHOST_SIZE;
          const enterFrom = isScout
            ? -offscreen
            : i % 2 === 0
              ? -offscreen
              : offscreen;
          const enterX = interpolate(sp, [0, 1], [enterFrom, 0]);

          const settled = frame > delay + 12;
          const float = settled
            ? Math.sin((frame - delay) * 0.12 + (i + 1) * 0.9) * 4.5
            : 0;

          const op = interpolate(sp, [0, 0.2], [0, 1], {
            extrapolateRight: "clamp",
          });

          return (
            <div
              key={ghost.name}
              style={{
                position: "absolute",
                left: targetX + enterX,
                top: targetY + float,
                opacity: op,
              }}
            >
              <Ghost color={ghost.color} rects={ghost.rects} scale={GHOST_SCALE} />
            </div>
          );
        })}

        {/* Terminal text — bottom-aligned, uniform white */}
        <div
          style={{
            position: "absolute",
            left: textLeft,
            right: textLeft,
            bottom: textBottom,
            fontFamily: "'SF Mono', 'Menlo', 'Courier New', monospace",
            fontSize: 28,
            lineHeight: 2.2,
            color: "#e0e0e0",
          }}
        >
          {showCmd && (
            <div>
              {cmd.visible}
              {cursorLine === 1 && cursorEl}
            </div>
          )}

          {showInstall && (
            <div>
              {install.visible}
              {cursorLine === 2 && cursorEl}
            </div>
          )}

          {showLink && (
            <div>
              {link.visible}
              {cursorLine === 3 && cursorEl}
            </div>
          )}
        </div>
      </div>
    </AbsoluteFill>
  );
};
